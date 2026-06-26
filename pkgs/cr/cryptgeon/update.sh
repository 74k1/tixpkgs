#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
pkg_file="$root/pkgs/cr/cryptgeon/default.nix"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$pkg_file")"
# 1st hash = source, 2nd hash = pnpm deps
old_src_hash="$(perl -ne 'if (/^\s*hash = "([^"]+)";/) { $i++; print $1 if $i == 1 }' "$pkg_file")"
old_pnpm_hash="$(perl -ne 'if (/^\s*hash = "([^"]+)";/) { $i++; print $1 if $i == 2 }' "$pkg_file")"
old_cargo_hash="$(perl -ne 'print $1 if /^\s*cargoHash = "([^"]+)";/' "$pkg_file")"

# Get latest GitHub release tag
new_version="$(curl -fsSL 'https://api.github.com/repos/cupcakearmy/cryptgeon/releases/latest' | jq -r '.tag_name // empty')"
if [[ -z "$new_version" ]]; then
  echo "failed to resolve latest cryptgeon release tag" >&2
  exit 1
fi
new_version="${new_version#v}"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_cargo_hash" || -z "$old_pnpm_hash" ]]; then
  echo "failed to read current version/hashes from $pkg_file" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" ]]; then
  echo "cryptgeon is already at the latest version ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

# Update version + source hash
archive="https://github.com/cupcakearmy/cryptgeon/archive/refs/tags/v${new_version}.tar.gz"
new_src_hash="$(nix store prefetch-file --json --unpack "$archive" | jq -r '.hash')"

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC="$old_src_hash" NEW_SRC="$new_src_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_SRC}\E";/hash = "$ENV{NEW_SRC}";/ or die "failed to replace source hash\n";
' "$pkg_file"

# Replace both cargoHash and pnpm hash with fake, build, extract both
FAKE="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
perl -0pi -e '
  s/cargoHash = "\Q$ENV{OLD_CARGO_HASH}\E";/cargoHash = "$ENV{FAKE}";/
    or die "failed to replace cargoHash\n";
' "$pkg_file"
perl -0pi -e '
  s/hash = "\Q$ENV{OLD_PNPM_HASH}\E";/hash = "$ENV{FAKE}";/
    or die "failed to replace pnpm hash\n";
' "$pkg_file"

echo "building to compute dependency hashes (pnpm + cargo)..." >&2
build_output="$(nix build --no-link "path:$root#cryptgeon" 2>&1 || true)"

# Extract hashes from build output
# Order: pnpm deps builds first, then cargo vendor
new_pnpm_hash="$(echo "$build_output" | grep -oP 'got:\s+\Ksha256-\S+' | head -1)"
new_cargo_hash="$(echo "$build_output" | grep -oP 'got:\s+\Ksha256-\S+' | tail -1)"

if [[ -z "$new_pnpm_hash" ]]; then
  echo "failed to extract new pnpm deps hash from build output:" >&2
  echo "$build_output" >&2
  exit 1
fi
if [[ -z "$new_cargo_hash" ]]; then
  echo "failed to extract new cargoHash from build output:" >&2
  echo "$build_output" >&2
  exit 1
fi

echo "  pnpmDeps hash: $new_pnpm_hash" >&2
echo "  cargoHash: $new_cargo_hash" >&2

# Replace hashes
perl -0pi -e '
  s/hash = "\Q$ENV{FAKE}\E";/hash = "$ENV{NEW_PNPM_HASH}";/
    or die "failed to replace pnpm hash\n";
' "$pkg_file"
export OLD_PNPM_HASH NEW_PNPM_HASH

perl -0pi -e '
  s/cargoHash = "\Q$ENV{FAKE}\E";/cargoHash = "$ENV{NEW_CARGO_HASH}";/
    or die "failed to replace cargoHash\n";
' "$pkg_file"
export OLD_CARGO_HASH NEW_CARGO_HASH

# Final verification build
echo "final verification build..." >&2
nix build --no-link "path:$root#cryptgeon" 2>&1 || {
  echo "final build failed — something is still wrong" >&2
  exit 1
}

printf '[{"attrPath":"cryptgeon","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$pkg_file"

#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
nix_file="$root/pkgs/po/powersync-service/default.nix"
repo="powersync-ja/powersync-service"

# The nix file contains two `hash = "..."` lines: the source hash first, then
# the pnpmDeps hash.
mapfile -t old_hashes < <(perl -ne 'print "$1\n" if /^\s*hash = "([^"]+)";/' "$nix_file")
old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$nix_file")"
old_src_hash="${old_hashes[0]}"
old_pnpm_hash="${old_hashes[1]}"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_pnpm_hash" ]]; then
  echo "failed to read current version/hashes from $nix_file" >&2
  exit 1
fi

# Get latest release tag from GitHub
api="https://api.github.com/repos/$repo/releases/latest"
release="$(curl -fsSL "$api")"
tag="$(jq -r '.tag_name // empty' <<< "$release")"

if [[ -z "$tag" ]]; then
  echo "failed to read latest release tag from $api" >&2
  exit 1
fi

if [[ "$tag" != v* ]]; then
  echo "unexpected release tag: $tag" >&2
  exit 1
fi

new_version="${tag#v}"

# Prefetch new source hash (same as fetchFromGitHub: the unpacked tarball)
new_src_hash="$(
  nix --extra-experimental-features nix-command store prefetch-file \
    --json --unpack --name source \
    "https://github.com/$repo/archive/refs/tags/${tag}.tar.gz" \
    | jq -r '.hash'
)"

if [[ -z "$new_src_hash" ]]; then
  echo "failed to prefetch $repo source for $tag" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" && "$old_src_hash" == "$new_src_hash" ]]; then
  echo "powersync-service is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

echo "Updating powersync-service: $old_version -> $new_version" >&2

# Update version and src hash, replace pnpmDeps hash with a fake to discover
# the real one
OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC_HASH="$old_src_hash" NEW_SRC_HASH="$new_src_hash" \
OLD_PNPM_HASH="$old_pnpm_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_SRC_HASH}\E";/hash = "$ENV{NEW_SRC_HASH}";/ or die "failed to replace src hash\n";
  s/hash = "\Q$ENV{OLD_PNPM_HASH}\E";/hash = lib.fakeHash;/ or die "failed to replace pnpmDeps hash\n";
' "$nix_file"

# Build the pnpmDeps fetcher with a fake hash to discover the real one
get_mismatch_hash() {
  local attr="$1"
  local log
  log="$(mktemp)"
  if nix --extra-experimental-features nix-command build \
    --no-link --print-build-logs "$root#$attr" >"$log" 2>&1; then
    echo "expected $attr to fail with a fake hash, but it built successfully" >&2
    exit 1
  fi
  local got
  got="$(perl -ne 'print $1 if /^\s*got:\s+(sha256-\S+)/' "$log" | tail -n1)"
  if [[ -z "$got" ]]; then
    echo "failed to extract hash mismatch for $attr" >&2
    tail -20 "$log" >&2
    exit 1
  fi
  printf '%s\n' "$got"
}

new_pnpm_hash="$(get_mismatch_hash 'powersync-service.pnpmDeps')"

# Replace the fake hash with the real one
NEW_PNPM_HASH="$new_pnpm_hash" perl -0pi -e '
  s/hash = lib\.fakeHash;/hash = "$ENV{NEW_PNPM_HASH}";/ or die "failed to replace fake pnpmDeps hash\n";
' "$nix_file"

printf '[{"attrPath":"powersync-service","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$nix_file"

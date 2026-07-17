#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash git gawk jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/tr/trek/default.nix"
repo="https://github.com/mauriceboe/TREK"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_src_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"
old_npm_hash="$(perl -ne 'print $1 if /^\s*npmDepsHash = "([^"]+)";/' "$package_file")"

new_version="$({
  git ls-remote --tags --refs "$repo.git" \
    | awk -F/ '$NF ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { sub(/^v/, "", $NF); print $NF }' \
    | sort -V \
    | tail -n1
})"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_npm_hash" || -z "$new_version" ]]; then
  echo "failed to read current or latest trek version/hashes" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" ]]; then
  echo "trek is already at $new_version; refreshing hashes anyway." >&2
fi

new_src_hash="$(nix --extra-experimental-features nix-command store prefetch-file --json --unpack \
  "$repo/archive/refs/tags/v$new_version.tar.gz" | jq -r '.hash')"

fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC_HASH="$old_src_hash" NEW_SRC_HASH="$new_src_hash" \
OLD_NPM_HASH="$old_npm_hash" FAKE_HASH="$fake_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_SRC_HASH}\E";/hash = "$ENV{NEW_SRC_HASH}";/ or die "failed to replace source hash\n";
  s/npmDepsHash = "\Q$ENV{OLD_NPM_HASH}\E";/npmDepsHash = "$ENV{FAKE_HASH}";/ or die "failed to replace npmDepsHash\n";
' "$package_file"

# Discover the real npmDepsHash: with a fake hash the fetchNpmDeps
# fixed-output derivation fails and prints the expected `got:` hash.
log="$(mktemp)"
if nix build --no-link --print-build-logs "$root#trek" >"$log" 2>&1; then
  echo "expected the npmDeps FOD to fail with a fake hash, but the build succeeded" >&2
  rm -f "$log"
  exit 1
fi
new_npm_hash="$(perl -ne 'print $1 if /^\s*got:\s+(sha256-[^\s]+)/' "$log" | tail -n1)"
if [[ -z "$new_npm_hash" ]]; then
  echo "failed to extract the npmDepsHash mismatch:" >&2
  cat "$log" >&2
  rm -f "$log"
  exit 1
fi
rm -f "$log"

FAKE_HASH="$fake_hash" NEW_NPM_HASH="$new_npm_hash" perl -0pi -e '
  s/npmDepsHash = "\Q$ENV{FAKE_HASH}\E";/npmDepsHash = "$ENV{NEW_NPM_HASH}";/ or die "failed to set real npmDepsHash\n";
' "$package_file"

printf '[{"attrPath":"trek","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

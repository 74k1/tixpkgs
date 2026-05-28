#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash git gawk jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/ry/rybbit/default.nix"
repo="https://github.com/rybbit-io/rybbit"
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_src_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"
mapfile -t old_npm_hashes < <(perl -ne 'print "$1\n" if /^\s*npmDepsHash = "([^"]+)";/' "$package_file")
old_client_hash="${old_npm_hashes[0]:-}"
old_server_hash="${old_npm_hashes[1]:-}"

new_version="$({
  git ls-remote --tags --refs "$repo.git" \
    | awk -F/ '$NF ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { sub(/^v/, "", $NF); print $NF }' \
    | sort -V \
    | tail -n1
})"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_client_hash" || -z "$old_server_hash" || -z "$new_version" ]]; then
  echo "failed to read current or latest rybbit version/hashes" >&2
  exit 1
fi

new_src_hash="$(nix --extra-experimental-features nix-command store prefetch-file --json --unpack \
  "$repo/archive/v$new_version.tar.gz" | jq -r '.hash')"

if [[ "$old_version" == "$new_version" && "$old_src_hash" == "$new_src_hash" ]]; then
  echo "rybbit source is already at $new_version; refreshing npm hashes anyway." >&2
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC_HASH="$old_src_hash" NEW_SRC_HASH="$new_src_hash" \
OLD_CLIENT_HASH="$old_client_hash" OLD_SERVER_HASH="$old_server_hash" FAKE_HASH="$fake_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_SRC_HASH}\E";/hash = "$ENV{NEW_SRC_HASH}";/ or die "failed to replace source hash\n";
  s/npmDepsHash = "\Q$ENV{OLD_CLIENT_HASH}\E";/npmDepsHash = lib.fakeHash;/ or die "failed to replace client npmDepsHash\n";
  s/npmDepsHash = "\Q$ENV{OLD_SERVER_HASH}\E";/npmDepsHash = lib.fakeHash;/ or die "failed to replace server npmDepsHash\n";
' "$package_file"

get_mismatch_hash() {
  local attr="$1"
  local log
  log="$(mktemp)"
  if nix build --no-link --print-build-logs "$root#$attr" >"$log" 2>&1; then
    echo "expected $attr to fail with a fake hash, but it built successfully" >&2
    rm -f "$log"
    exit 1
  fi
  local got
  got="$(perl -ne 'print $1 if /^\s*got:\s+(sha256-[^\s]+)/' "$log" | tail -n1)"
  if [[ -z "$got" ]]; then
    echo "failed to extract hash mismatch for $attr" >&2
    cat "$log" >&2
    rm -f "$log"
    exit 1
  fi
  rm -f "$log"
  printf '%s\n' "$got"
}

new_client_hash="$(get_mismatch_hash 'rybbit.passthru.rybbit-client')"
FAKE_HASH="$fake_hash" NEW_CLIENT_HASH="$new_client_hash" perl -0pi -e '
  s/npmDepsHash = lib\.fakeHash;/npmDepsHash = "$ENV{NEW_CLIENT_HASH}";/ or die "failed to replace client fake hash\n";
' "$package_file"

new_server_hash="$(get_mismatch_hash 'rybbit')"
FAKE_HASH="$fake_hash" NEW_SERVER_HASH="$new_server_hash" perl -0pi -e '
  s/npmDepsHash = lib\.fakeHash;/npmDepsHash = "$ENV{NEW_SERVER_HASH}";/ or die "failed to replace server fake hash\n";
' "$package_file"

printf '[{"attrPath":"rybbit","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash git gawk perl coreutils nix jq
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/g3/g3m/default.nix"
repo="https://github.com/y114git/G3M"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_src_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file" | head -1)"

new_version="$({
  git ls-remote --tags --refs "$repo.git" \
    | awk -F/ '$NF ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ { print $NF }' \
    | sort -V \
    | tail -n1
})"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$new_version" ]]; then
  echo "failed to read current or latest g3m version/hash" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" ]]; then
  echo "g3m is already at $new_version." >&2
  printf '[]\n'
  exit 0
fi

new_src_hash="$(nix --extra-experimental-features nix-command store prefetch-file --json --unpack \
  "$repo/archive/refs/tags/$new_version.tar.gz" | jq -r '.hash')"

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC_HASH="$old_src_hash" NEW_SRC_HASH="$new_src_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_SRC_HASH}\E";/hash = "$ENV{NEW_SRC_HASH}";/ or die "failed to replace source hash\n";
' "$package_file"

printf '[{"attrPath":"g3m","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash git gawk gnused jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/id/ida-ios-helper/default.nix"
repo="https://github.com/yoavst/ida-ios-helper"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"

new_version="$({
  git ls-remote --tags --refs "$repo.git" \
    | awk -F/ '{print $NF}' \
    | sed 's/^v//' \
    | sort -V \
    | tail -n1
})"

if [[ -z "$old_version" || -z "$old_hash" || -z "$new_version" ]]; then
  echo "failed to read current or latest ida-ios-helper version/hash" >&2
  exit 1
fi

new_hash="$(nix --extra-experimental-features nix-command store prefetch-file --json --unpack \
  "$repo/archive/$new_version.tar.gz" | jq -r '.hash')"

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "ida-ios-helper is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "failed to replace hash\n";
' "$package_file"

printf '[{"attrPath":"ida-ios-helper","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

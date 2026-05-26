#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl git jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/mt/mtkclient/default.nix"
api="https://api.github.com/repos/bkerler/mtkclient/commits/main"

commit="$(curl -fsSL "$api")"
new_rev="$(jq -r '.sha // empty' <<< "$commit")"
new_version="${new_rev:0:7}"

if [[ -z "$new_rev" || -z "$new_version" ]]; then
  echo "failed to resolve latest mtkclient commit from $api" >&2
  exit 1
fi

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_rev="$(perl -ne 'print $1 if /^\s*rev = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"

if [[ -z "$old_version" || -z "$old_rev" || -z "$old_hash" ]]; then
  echo "failed to read current version, rev or hash from $package_file" >&2
  exit 1
fi

archive="https://github.com/bkerler/mtkclient/archive/$new_rev.tar.gz"
new_hash="$(nix --extra-experimental-features nix-command store prefetch-file --json --unpack "$archive" | jq -r '.hash')"

if [[ "$old_version" == "$new_version" && "$old_rev" == "$new_rev" && "$old_hash" == "$new_hash" ]]; then
  echo "mtkclient is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_REV="$old_rev" NEW_REV="$new_rev" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/rev = "\Q$ENV{OLD_REV}\E";/rev = "$ENV{NEW_REV}";/ or die "failed to replace rev\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "failed to replace hash\n";
' "$package_file"

printf '[{"attrPath":"mtkclient","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

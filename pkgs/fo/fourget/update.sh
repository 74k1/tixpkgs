#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash git gawk jq perl coreutils nix-prefetch-git nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/fo/fourget/default.nix"
repo="https://git.lolcat.ca/lolcat/4get.git"

new_rev="$(git ls-remote "$repo" HEAD | awk '{print $1}')"
if [[ -z "$new_rev" ]]; then
  echo "failed to resolve latest 4get HEAD from $repo" >&2
  exit 1
fi
tmprepo="$(mktemp -d)"
trap 'rm -rf "$tmprepo"' EXIT
git -C "$tmprepo" init --quiet
git -C "$tmprepo" remote add origin "$repo"
git -C "$tmprepo" fetch --quiet --depth 1 origin "$new_rev"
new_date="$(git -C "$tmprepo" show -s --format=%cs FETCH_HEAD)"
new_version="unstable-$new_date"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_rev="$(perl -ne 'print $1 if /^\s*rev = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"

if [[ -z "$old_version" || -z "$old_rev" || -z "$old_hash" ]]; then
  echo "failed to read current version, rev or hash from $package_file" >&2
  exit 1
fi

prefetch="$(nix-prefetch-git --quiet --url "$repo" --rev "$new_rev")"
raw_hash="$(jq -r '.hash // .sha256 // empty' <<< "$prefetch")"
if [[ -z "$raw_hash" ]]; then
  echo "failed to prefetch 4get rev $new_rev" >&2
  exit 1
fi
if [[ "$raw_hash" == sha256-* ]]; then
  new_hash="$raw_hash"
else
  new_hash="$(nix --extra-experimental-features nix-command hash convert --hash-algo sha256 --to sri "$raw_hash")"
fi

if [[ "$old_version" == "$new_version" && "$old_rev" == "$new_rev" && "$old_hash" == "$new_hash" ]]; then
  echo "4get is already up to date ($new_version)." >&2
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

printf '[{"attrPath":"fourget","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

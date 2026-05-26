#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash git gawk jq perl coreutils nix-prefetch-git nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/wa/waterfox/default.nix"
repo="https://github.com/BrowserWorks/Waterfox"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"

new_version="$({
  git ls-remote --tags --refs "$repo.git" \
    | awk -F/ '$NF ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ { print $NF }' \
    | sort -V \
    | tail -n1
})"

if [[ -z "$old_version" || -z "$old_hash" || -z "$new_version" ]]; then
  echo "failed to read current or latest Waterfox version/hash" >&2
  exit 1
fi

prefetch="$(
  GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0=url.https://github.com/.insteadOf \
  GIT_CONFIG_VALUE_0=git@github.com: \
  nix-prefetch-git --quiet --fetch-submodules --url "$repo" --rev "$new_version"
)"
new_hash="$(jq -r '.hash // .sha256 // empty' <<< "$prefetch")"

if [[ -z "$new_hash" ]]; then
  echo "failed to prefetch Waterfox tag $new_version" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "waterfox is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "failed to replace hash\n";
' "$package_file"

printf '[{"attrPath":"waterfox","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

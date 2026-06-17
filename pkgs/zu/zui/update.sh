#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/zu/zui/default.nix"
repo="brimdata/zui"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"

release="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")"
new_version="$(jq -r '.tag_name // empty' <<< "$release")"
new_version="${new_version#v}"

if [[ -z "$old_version" || -z "$old_hash" || -z "$new_version" ]]; then
  echo "failed to read current or latest zui version/hash" >&2
  exit 1
fi

url="https://github.com/$repo/releases/download/v${new_version}/zui_${new_version}_amd64.deb"

new_hash="$(nix --extra-experimental-features nix-command store prefetch-file --json "$url" | jq -r '.hash')"

if [[ -z "$new_hash" ]]; then
  echo "failed to prefetch zui $new_version" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "zui is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "failed to replace hash\n";
' "$package_file"

printf '[{"attrPath":"zui","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

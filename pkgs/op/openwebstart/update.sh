#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
pkg_file="$root/pkgs/op/openwebstart/default.nix"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$pkg_file" | head -1)"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$pkg_file" | head -1)"

new_version="$(curl -fsSL 'https://api.github.com/repos/karakun/OpenWebStart/releases/latest' \
  | jq -r '.tag_name // empty')"
new_version="${new_version#v}"

if [[ -z "$old_version" || -z "$old_hash" || -z "$new_version" ]]; then
  echo "failed to resolve version or hash" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" ]]; then
  echo "openwebstart is already at $new_version." >&2
  printf '[]\n'
  exit 0
fi

deb_version="${new_version//./_}"
url="https://github.com/karakun/OpenWebStart/releases/download/v${new_version}/OpenWebStart_linux_${deb_version}.deb"

new_hash="$(nix store prefetch-file --json "$url" | jq -r '.hash')"

if [[ -z "$new_hash" ]]; then
  echo "failed to prefetch $url" >&2
  exit 1
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "version\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "hash\n";
' "$pkg_file"

printf '[{"attrPath":"openwebstart","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$pkg_file"

#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl git perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/br/brscan-skey/default.nix"
# Brother's generic x86_64 RPM download page for Scan-key-tool.
download_page="https://support.brother.com/g/b/downloadhowto.aspx?c=us&lang=en&prod=mfcl3770cdw_us_eu_as&os=127&dlid=dlf006650_000&flang=4&type3=568"

page="$(curl -fsSL "$download_page")"
url="$(printf '%s' "$page" | perl -0ne 'print $1 if /id="downloadfile"\s+href="([^"]+)"/')"

if [[ -z "$url" ]]; then
  echo "failed to find brscan-skey download URL from $download_page" >&2
  exit 1
fi

if [[ "$url" =~ brscan-skey-([^/]+)\.x86_64\.rpm$ ]]; then
  new_version="${BASH_REMATCH[1]}"
else
  echo "failed to parse brscan-skey version from URL: $url" >&2
  exit 1
fi

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"

if [[ -z "$old_version" || -z "$old_hash" ]]; then
  echo "failed to read current version or hash from $package_file" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

download="$tmpdir/brscan-skey-$new_version.x86_64.rpm"
curl -fsSL -o "$download" "$url"
new_hash="$(nix --extra-experimental-features nix-command hash file --type sha256 --sri "$download")"

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "brscan-skey is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "failed to replace hash\n";
' "$package_file"

printf '[{"attrPath":"brscan-skey","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

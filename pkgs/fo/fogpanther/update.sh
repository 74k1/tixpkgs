#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl git perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/fo/fogpanther/default.nix"
installer_url="https://fogpanther.com/install.sh"

installer="$(curl -fsSL "$installer_url")"

new_version="$(printf '%s' "$installer" | perl -ne 'print $1 if /^VERSION="([^"]+)"/')"
base_url="$(printf '%s' "$installer" | perl -ne 'print $1 if /^BASE_URL="([^"]+)"/')"
token="$(printf '%s' "$installer" | perl -ne 'print $1 if /^TOKEN="([^"]+)"/')"

if [[ -z "$new_version" ]]; then
  echo "failed to find Fog Panther VERSION in $installer_url" >&2
  exit 1
fi

if [[ -z "$base_url" || -z "$token" ]]; then
  echo "failed to find Fog Panther download URL/token in $installer_url" >&2
  exit 1
fi

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*outputHash = "([^"]+)";/' "$package_file")"

if [[ -z "$old_version" || -z "$old_hash" ]]; then
  echo "failed to read current version or outputHash from $package_file" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

download="$tmpdir/fogpanther-$new_version.tar.xz"
curl -fsSL -o "$download" "${base_url}/tarball?arch=x86_64&token=${token}"

new_hash="$(nix --extra-experimental-features nix-command hash file --type sha256 --sri "$download")"

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "fogpanther is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/outputHash = "\Q$ENV{OLD_HASH}\E";/outputHash = "$ENV{NEW_HASH}";/ or die "failed to replace outputHash\n";
' "$package_file"

printf '[{"attrPath":"fogpanther","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

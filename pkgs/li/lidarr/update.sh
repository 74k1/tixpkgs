#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/li/lidarr/default.nix"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"

# Find the latest pre-release (develop) from GitHub API
release="$(curl -fsSL 'https://api.github.com/repos/Lidarr/Lidarr/releases?per_page=20' \
  | jq -r '[.[] | select(.prerelease == true)] | first')"

new_version="$(jq -r '.tag_name // empty' <<< "$release")"
# Strip leading 'v' if present
new_version="${new_version#v}"

if [[ -z "$old_version" || -z "$old_hash" || -z "$new_version" ]]; then
  echo "failed to read current or latest Lidarr version/hash" >&2
  exit 1
fi

url="https://github.com/Lidarr/Lidarr/releases/download/v${new_version}/Lidarr.develop.${new_version}.linux-core-x64.tar.gz"

new_hash="$(nix-prefetch-url --type sha256 --unpack "$url" 2>/dev/null \
  | xargs nix hash to-sri --type sha256)"

if [[ -z "$new_hash" ]]; then
  echo "failed to prefetch Lidarr $new_version" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "lidarr is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "failed to replace hash\n";
' "$package_file"

printf '[{"attrPath":"lidarr","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

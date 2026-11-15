#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl git perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/se/septabee/package.nix"
# The download button on the homepage reads this manifest.
manifest_url="https://septabee.nekoweb.org/latest"

url="$(curl -fsSL "$manifest_url" | perl -ne 'print $1 if /^linux-offline (https:\/\/\S+)/')"

# The package builds its URL from the version, so the manifest URL must keep that form.
if [[ "$url" =~ ^https://downloads\.septabee\.com/SEPTABEE_DOWNLOADS/septabee_linux_(.+)_offline\.7z$ ]]; then
  new_version="${BASH_REMATCH[1]}"
else
  echo "failed to parse the Septabee linux-offline URL from $manifest_url: '$url'" >&2
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

download="$tmpdir/septabee.7z"
curl -fsSL -o "$download" "$url"
new_hash="$(nix --extra-experimental-features nix-command hash file --type sha256 --sri "$download")"

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "septabee is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "failed to replace hash\n";
' "$package_file"

printf '[{"attrPath":"septabee","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

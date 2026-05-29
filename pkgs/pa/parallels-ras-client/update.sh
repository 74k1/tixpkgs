#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl git jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/pa/parallels-ras-client/default.nix"
readme_file="$root/README.md"
base="https://download.parallels.com/website_links"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"

index="$(curl -fsSL "$base/ras/index.json")"
latest_version_key="$(jq -r 'keys | sort_by(split(".") | map(tonumber)) | last' <<< "$index")"
builds_path="$(jq -r --arg version "$latest_version_key" '.[$version].builds.en_US' <<< "$index")"
builds="$(curl -fsSL "$base/$builds_path")"

new_url="$(jq -r '.. | objects | select(.subcategory? == "Linux" and .name? == "x64") | .files["Linux Client - tar.bz2 64-bit"] // empty' <<< "$builds" | head -n1)"
new_version="$(perl -ne 'print $1 if /RASClient-([0-9.]+)_x86_64[.]tar[.]bz2/' <<< "$new_url")"

if [[ -z "$old_version" || -z "$old_hash" || -z "$new_version" || -z "$new_url" ]]; then
  echo "failed to read current or latest Parallels RAS Client metadata" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

archive="$tmpdir/ras-client.tar.bz2"
curl -fsSL -o "$archive" "$new_url"
new_hash="$(nix --extra-experimental-features nix-command hash file --type sha256 --sri "$archive")"

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "parallels-ras-client is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "failed to replace hash\n";
' "$package_file"

if [[ -f "$readme_file" ]]; then
  OLD_VERSION="$old_version" NEW_VERSION="$new_version" perl -0pi -e '
    s/(\| `parallels-ras-client` \| `)\Q$ENV{OLD_VERSION}\E(` \|)/$1$ENV{NEW_VERSION}$2/;
  ' "$readme_file"
fi

printf '[{"attrPath":"parallels-ras-client","oldVersion":"%s","newVersion":"%s","files":["%s","%s"]}]\n' \
  "$old_version" "$new_version" "$package_file" "$readme_file"

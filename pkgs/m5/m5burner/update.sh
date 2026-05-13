#!/usr/bin/env nix
#! nix shell nixpkgs#bash nixpkgs#curl nixpkgs#git nixpkgs#libxml2 nixpkgs#perl nixpkgs#coreutils nixpkgs#nix --command bash
set -euo pipefail

page="https://docs.m5stack.com/en/uiflow/m5burner/intro"
xpath="/html/body/div[1]/div/div/div/div[1]/div[3]/div[3]/div/div[1]/table/tbody/tr[3]/td[2]/a"
root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/m5/m5burner/default.nix"

url="$(curl -fsSL "$page" \
  | xmllint --html --xpath "string($xpath/@href)" - 2>/dev/null)"

if [[ -z "$url" ]]; then
  echo "failed to find M5Burner download URL using XPath: $xpath" >&2
  exit 1
fi

if [[ "$url" =~ ^// ]]; then
  url="https:$url"
elif [[ "$url" =~ ^/ ]]; then
  url="https://docs.m5stack.com$url"
fi

if [[ "$url" =~ M5Burner-v(.+)-linux-x64\.zip$ ]]; then
  new_version="${BASH_REMATCH[1]}"
else
  echo "failed to parse M5Burner version from URL: $url" >&2
  exit 1
fi

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

download="$tmpdir/M5Burner-v$new_version-linux-x64.zip"
curl -fsSL --referer "https://m5burner-cdn.m5stack.com/" -o "$download" "$url"
new_hash="$(nix --extra-experimental-features nix-command hash file --type sha256 --sri "$download")"

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "m5burner is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "failed to replace hash\n";
' "$package_file"

printf '[{"attrPath":"m5burner","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

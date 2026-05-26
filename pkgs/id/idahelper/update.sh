#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl git jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/id/idahelper/default.nix"
pypi="https://pypi.org/pypi/idahelper/json"

json="$(curl -fsSL "$pypi")"
new_version="$(jq -r '.info.version // empty' <<< "$json")"
url="$(jq -r --arg v "$new_version" '.releases[$v][] | select(.packagetype == "sdist") | .url' <<< "$json" | head -n1)"

if [[ -z "$new_version" || -z "$url" ]]; then
  echo "failed to find idahelper latest sdist on PyPI" >&2
  exit 1
fi

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -ne 'print $1 if /^\s*sha256 = "([^"]+)";/' "$package_file")"

if [[ -z "$old_version" || -z "$old_hash" ]]; then
  echo "failed to read current version or sha256 from $package_file" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

download="$tmpdir/idahelper-$new_version.tar.gz"
curl -fsSL -o "$download" "$url"
new_hash="$(nix --extra-experimental-features nix-command hash file --type sha256 --sri "$download")"

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "idahelper is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/sha256 = "\Q$ENV{OLD_HASH}\E";/sha256 = "$ENV{NEW_HASH}";/ or die "failed to replace sha256\n";
' "$package_file"

printf '[{"attrPath":"idahelper","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

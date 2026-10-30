#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash git gawk jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/bl/blink-qt/package.nix"
repo="https://github.com/AGProjects/blink-qt"

# The repository also carries release-*, resolute-*, sipsimple-* and
# <major>.<minor>.<patch>-linux tags, so only plain numeric tags are releases
# of blink-qt.
new_version="$({
  git ls-remote --tags --refs "$repo.git" \
    | awk -F/ '$NF ~ /^[0-9]+(\.[0-9]+)+$/ { print $NF }' \
    | sort -V \
    | tail -n1
})"

if [[ -z "$new_version" ]]; then
  echo "failed to resolve the latest numeric blink-qt tag from $repo" >&2
  exit 1
fi

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -0ne 'print $1 if /src = fetchFromGitHub \{.*?hash = "([^"]+)";/s' "$package_file")"

if [[ -z "$old_version" || -z "$old_hash" ]]; then
  echo "failed to read current version or hash from $package_file" >&2
  exit 1
fi

new_hash="$(
  nix --extra-experimental-features nix-command store prefetch-file \
    --json --unpack --name source \
    "$repo/archive/refs/tags/${new_version}.tar.gz" \
    | jq -r '.hash'
)"

if [[ -z "$new_hash" ]]; then
  echo "failed to prefetch blink-qt source for $new_version" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "blink-qt is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

echo "Updating blink-qt: $old_version -> $new_version" >&2

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/(src = fetchFromGitHub \{.*?hash = ")\Q$ENV{OLD_HASH}\E(";)/$1$ENV{NEW_HASH}$2/s or die "failed to replace src hash\n";
' "$package_file"

printf '[{"attrPath":"blink-qt","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

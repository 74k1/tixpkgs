#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
pkg_file="$root/pkgs/de/degoog/default.nix"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$pkg_file")"
old_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$pkg_file")"

# Get latest GitHub release tag
new_version="$(curl -fsSL 'https://api.github.com/repos/degoog-org/degoog/releases/latest' | jq -r '.tag_name // empty')"
if [[ -z "$new_version" ]]; then
  echo "failed to resolve latest degoog release tag" >&2
  exit 1
fi

if [[ -z "$old_version" || -z "$old_hash" ]]; then
  echo "failed to read current version or hash from $pkg_file" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" ]]; then
  echo "degoog is already at the latest version ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

# Prefetch new release tarball
archive="https://github.com/degoog-org/degoog/releases/download/${new_version}/degoog_${new_version}_prebuild.tar.gz"
new_hash="$(nix store prefetch-file --json "$archive" | jq -r '.hash')"
if [[ -z "$new_hash" ]]; then
  echo "failed to prefetch degoog release tarball $archive" >&2
  exit 1
fi

# Update version + hash
OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_HASH}\E";/hash = "$ENV{NEW_HASH}";/ or die "failed to replace hash\n";
' "$pkg_file"

# Verify it builds
echo "final verification build..." >&2
nix build --no-link "path:$root#degoog" 2>&1 || {
  echo "final build failed — something is still wrong" >&2
  exit 1
}

printf '[{"attrPath":"degoog","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$pkg_file"

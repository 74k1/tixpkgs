#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix nix-prefetch-git
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
pkg_file="$root/pkgs/yo/yopass/default.nix"
web_file="$root/pkgs/yo/yopass/website.nix"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$pkg_file")"
old_src_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$pkg_file")"
old_vendor_hash="$(perl -ne 'print $1 if /^\s*vendorHash = "([^"]+)";/' "$pkg_file")"
old_yarn_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$web_file")"

# Get latest GitHub release tag
new_version="$(curl -fsSL 'https://api.github.com/repos/jhaals/yopass/releases/latest' | jq -r '.tag_name // empty')"
if [[ -z "$new_version" ]]; then
  echo "failed to resolve latest yopass release tag" >&2
  exit 1
fi

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_vendor_hash" || -z "$old_yarn_hash" ]]; then
  echo "failed to read current version/hashes from $pkg_file or $web_file" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" ]]; then
  echo "yopass is already at the latest version ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

# Prefetch new source tarball
archive="https://github.com/jhaals/yopass/archive/refs/tags/${new_version}.tar.gz"
new_src_hash="$(nix store prefetch-file --json --unpack "$archive" | jq -r '.hash')"

# Update version + source hash in package file
OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC="$old_src_hash" NEW_SRC="$new_src_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_SRC}\E";/hash = "$ENV{NEW_SRC}";/ or die "failed to replace source hash\n";
' "$pkg_file"

# 1. Replace vendorHash with fake, build, extract real one
FAKE="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
perl -0pi -e '
  s/vendorHash = "\Q$ENV{OLD_VENDOR_HASH}\E";/vendorHash = "$ENV{FAKE}";/
    or die "failed to replace vendorHash\n";
' "$pkg_file"

echo "building to compute vendorHash..." >&2
vendor_build_output="$(nix build --no-link "path:$root#yopass" 2>&1 || true)"
new_vendor_hash="$(echo "$vendor_build_output" | grep -oP 'got:\s+\Ksha256-\S+' | head -1)"

if [[ -z "$new_vendor_hash" ]]; then
  echo "failed to extract new vendorHash from build output:" >&2
  echo "$vendor_build_output" >&2
  exit 1
fi
echo "  vendorHash: $new_vendor_hash" >&2
perl -0pi -e '
  s/vendorHash = "\Q$ENV{FAKE}\E";/vendorHash = "$ENV{NEW_VENDOR_HASH}";/
    or die "failed to replace vendorHash\n";
' "$pkg_file"
export OLD_VENDOR_HASH NEW_VENDOR_HASH

# 2. Replace yarn lock hash with fake, build, extract real one
perl -0pi -e '
  s/hash = "\Q$ENV{OLD_YARN_HASH}\E";/hash = "$ENV{FAKE}";/
    or die "failed to replace yarn hash\n";
' "$web_file"

echo "building to compute yarn cache hash..." >&2
yarn_build_output="$(nix build --no-link "path:$root#yopass" 2>&1 || true)"
new_yarn_hash="$(echo "$yarn_build_output" | grep -oP 'got:\s+\Ksha256-\S+' | head -1)"

if [[ -z "$new_yarn_hash" ]]; then
  echo "failed to extract new yarn cache hash from build output:" >&2
  echo "$yarn_build_output" >&2
  exit 1
fi
echo "  yarnHash: $new_yarn_hash" >&2
perl -0pi -e '
  s/hash = "\Q$ENV{FAKE}\E";/hash = "$ENV{NEW_YARN_HASH}";/
    or die "failed to replace yarn hash\n";
' "$web_file"
export OLD_YARN_HASH NEW_YARN_HASH

# Final build to verify everything works
echo "final verification build..." >&2
nix build --no-link "path:$root#yopass" 2>&1 || {
  echo "final build failed — something is still wrong" >&2
  exit 1
}

printf '[{"attrPath":"yopass","oldVersion":"%s","newVersion":"%s","files":["%s","%s"]}]\n' \
  "$old_version" "$new_version" "$pkg_file" "$web_file"
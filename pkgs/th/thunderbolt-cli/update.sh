#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix-prefetch-git nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/th/thunderbolt-cli/default.nix"
repo="thunderbird/thunderbolt"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_src_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"
old_node_hash="$(perl -ne 'print $1 if /^\s*outputHash = "([^"]+)";/' "$package_file")"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_node_hash" ]]; then
  echo "failed to read current version/hashes from $package_file" >&2
  exit 1
fi

# Get latest release tag from GitHub
api="https://api.github.com/repos/$repo/releases/latest"
release="$(curl -fsSL "$api")"
tag="$(jq -r '.tag_name // empty' <<< "$release")"

if [[ -z "$tag" ]]; then
  echo "failed to read latest release tag from $api" >&2
  exit 1
fi

if [[ "$tag" != v* ]]; then
  echo "unexpected release tag: $tag" >&2
  exit 1
fi

new_version="${tag#v}"

# Prefetch new source hash
prefetch="$(nix-prefetch-git --quiet --url "https://github.com/$repo" --rev "$tag")"
new_src_hash="$(jq -r '.hash // .sha256 // empty' <<< "$prefetch")"

if [[ -z "$new_src_hash" ]]; then
  echo "failed to prefetch $repo source for $tag" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" && "$old_src_hash" == "$new_src_hash" ]]; then
  echo "thunderbolt-cli is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

echo "Updating thunderbolt-cli: $old_version -> $new_version" >&2

# Update version and src hash, replace node hash with fake
OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC_HASH="$old_src_hash" NEW_SRC_HASH="$new_src_hash" \
OLD_NODE_HASH="$old_node_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_SRC_HASH}\E";/hash = "$ENV{NEW_SRC_HASH}";/ or die "failed to replace src hash\n";
  s/outputHash = "\Q$ENV{OLD_NODE_HASH}\E";/outputHash = lib.fakeHash;/ or die "failed to replace node outputHash\n";
' "$package_file"

# Build the node_modules with a fake hash to discover the real one
get_mismatch_hash() {
  local attr="$1"
  local log
  log="$(mktemp)"
  if nix build --no-link --print-build-logs "$root#$attr" >"$log" 2>&1; then
    echo "expected $attr to fail with a fake hash, but it built successfully" >&2
    rm -f "$log"
    exit 1
  fi
  local got
  got="$(perl -ne 'print $1 if /^\s*got:\s+(sha256-[^\s]+)/' "$log" | tail -n1)"
  if [[ -z "$got" ]]; then
    echo "failed to extract hash mismatch for $attr" >&2
    cat "$log" >&2
    rm -f "$log"
    exit 1
  fi
  rm -f "$log"
  printf '%s\n' "$got"
}

new_node_hash="$(get_mismatch_hash 'thunderbolt-cli.cliNodeModules')"

# Replace the fake hash with the real one
NEW_NODE_HASH="$new_node_hash" perl -0pi -e '
  s/outputHash = lib\.fakeHash;/outputHash = "$ENV{NEW_NODE_HASH}";/ or die "failed to replace fake outputHash\n";
' "$package_file"

printf '[{"attrPath":"thunderbolt-cli","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"
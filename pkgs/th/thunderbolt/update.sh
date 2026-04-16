#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix-prefetch-git nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/th/thunderbolt/default.nix"
repo="thunderbird/thunderbolt"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_src_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$package_file")"
mapfile -t old_node_hashes < <(perl -ne 'print "$1\n" if /^\s*outputHash = "([^"]+)";/' "$package_file")
old_frontend_hash="${old_node_hashes[0]:-}"
old_backend_hash="${old_node_hashes[1]:-}"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_frontend_hash" || -z "$old_backend_hash" ]]; then
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
  echo "thunderbolt is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

echo "Updating thunderbolt: $old_version -> $new_version" >&2

# Update version and src hash, replace node hashes with fake
OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC_HASH="$old_src_hash" NEW_SRC_HASH="$new_src_hash" \
OLD_FRONTEND_HASH="$old_frontend_hash" OLD_BACKEND_HASH="$old_backend_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/hash = "\Q$ENV{OLD_SRC_HASH}\E";/hash = "$ENV{NEW_SRC_HASH}";/ or die "failed to replace src hash\n";
  s/outputHash = "\Q$ENV{OLD_FRONTEND_HASH}\E";/outputHash = lib.fakeHash;/ or die "failed to replace frontend outputHash\n";
  s/outputHash = "\Q$ENV{OLD_BACKEND_HASH}\E";/outputHash = lib.fakeHash;/ or die "failed to replace backend outputHash\n";
' "$package_file"

# Build the node_modules with fake hashes to discover the real ones
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

new_frontend_hash="$(get_mismatch_hash 'thunderbolt.frontendNodeModules')"
new_backend_hash="$(get_mismatch_hash 'thunderbolt.backendNodeModules')"

# Replace the fake hashes with the real ones (frontend first, then backend)
NEW_FRONTEND_HASH="$new_frontend_hash" NEW_BACKEND_HASH="$new_backend_hash" \
perl -0pi -e '
  s/outputHash = lib\.fakeHash;/outputHash = "$ENV{NEW_FRONTEND_HASH}";/ or die "failed to replace frontend fake hash\n";
  s/outputHash = lib\.fakeHash;/outputHash = "$ENV{NEW_BACKEND_HASH}";/ or die "failed to replace backend fake hash\n";
' "$package_file"

printf '[{"attrPath":"thunderbolt","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"
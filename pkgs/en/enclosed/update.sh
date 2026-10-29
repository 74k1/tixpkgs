#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/en/enclosed/package.nix"
api="https://api.github.com/repos/CorentinTh/enclosed/releases/latest"

old_version="$(perl -ne 'print "$1\n" if /^\s*version = "([^"]+)";/' "$package_file")"
old_src_hash="$(perl -0ne 'print "$1\n" if /src = fetchFromGitHub \{.*?hash = "([^"]+)";/s' "$package_file")"
old_pnpm_hash="$(perl -0ne 'print "$1\n" if /pnpmDeps = fetchPnpmDeps \{.*?hash = "([^"]+)";/s' "$package_file")"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_pnpm_hash" ]]; then
  echo "failed to read current version/hashes from $package_file" >&2
  exit 1
fi

release="$(curl -fsSL "$api")"
tag="$(jq -r '.tag_name // empty' <<< "$release")"

if [[ -z "$tag" ]]; then
  echo "failed to read enclosed latest release tag from $api" >&2
  exit 1
fi

if [[ "$tag" != v* ]]; then
  echo "unexpected enclosed release tag: $tag" >&2
  exit 1
fi

new_version="${tag#v}"

new_src_hash="$(
  nix --extra-experimental-features nix-command store prefetch-file \
    --json --unpack --name source \
    "https://github.com/CorentinTh/enclosed/archive/refs/tags/${tag}.tar.gz" \
    | jq -r '.hash'
)"

if [[ -z "$new_src_hash" ]]; then
  echo "failed to prefetch enclosed source for $tag" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" && "$old_src_hash" == "$new_src_hash" ]]; then
  echo "enclosed is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

echo "Updating enclosed: $old_version -> $new_version" >&2

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC_HASH="$old_src_hash" NEW_SRC_HASH="$new_src_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/(src = fetchFromGitHub \{.*?hash = ")\Q$ENV{OLD_SRC_HASH}\E(";)/$1$ENV{NEW_SRC_HASH}$2/s or die "failed to replace src hash\n";
' "$package_file"

# The pnpm dependency hash depends on the lockfile in the new source tree, so it
# can only be computed by evaluating the updated package. Build the dependency
# fetcher with a deliberately wrong hash and read the real one from the error.
echo "Recomputing pnpmDeps hash..." >&2
perl -0pi -e '
  s/(pnpmDeps = fetchPnpmDeps \{.*?hash = ")[^"]+(";)/${1}sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=$2/s
    or die "failed to set placeholder pnpmDeps hash\n";
' "$package_file"

deps_error="$(
  nix --extra-experimental-features 'nix-command flakes' build \
    "$root#enclosed.pnpmDeps" --no-link 2>&1 || true
)"

new_pnpm_hash="$(grep -oE 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' <<< "$deps_error" | head -n1 | awk '{print $2}')"

if [[ -z "$new_pnpm_hash" ]]; then
  echo "failed to compute pnpmDeps hash for $new_version:" >&2
  echo "$deps_error" >&2
  exit 1
fi

echo "New pnpmDeps hash: $new_pnpm_hash" >&2

NEW_PNPM_HASH="$new_pnpm_hash" \
perl -0pi -e '
  s/(pnpmDeps = fetchPnpmDeps \{.*?hash = ")[^"]+(";)/${1}$ENV{NEW_PNPM_HASH}$2/s
    or die "failed to replace pnpmDeps hash\n";
' "$package_file"

printf '[{"attrPath":"enclosed","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

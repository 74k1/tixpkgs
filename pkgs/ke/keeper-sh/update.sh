#!/usr/bin/env nix
#! nix shell nixpkgs#bash nixpkgs#curl nixpkgs#git nixpkgs#jq nixpkgs#perl nixpkgs#coreutils nixpkgs#nix nixpkgs#nix-prefetch-git --command bash
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/ke/keeper-sh/default.nix"
api="https://api.github.com/repos/ridafkih/keeper.sh/releases/latest"

release="$(curl -fsSL "$api")"
tag="$(jq -r '.tag_name // empty' <<< "$release")"
new_version="${tag#v}"

if [[ -z "$tag" || -z "$new_version" || "$tag" == "$new_version" ]]; then
  echo "failed to read latest keeper.sh release tag from $api" >&2
  exit 1
fi

old_version="$(perl -0ne 'print $1 if /\n  version = "([^"]+)";\n\n  src = fetchFromGitHub/s' "$package_file")"
old_src_hash="$(perl -0ne 'print $1 if /src = fetchFromGitHub \{.*?hash = "([^"]+)";/s' "$package_file")"
old_modules_hash="$(perl -0ne 'print $1 if /outputHash = "([^"]+)";\n    outputHashAlgo/s' "$package_file")"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_modules_hash" ]]; then
  echo "failed to read current keeper version, source hash, or nodeModules hash from $package_file" >&2
  exit 1
fi

prefetch="$(nix-prefetch-git --quiet --url https://github.com/ridafkih/keeper.sh --rev "$tag")"
raw_src_hash="$(jq -r '.hash // .sha256 // empty' <<< "$prefetch")"
if [[ -z "$raw_src_hash" ]]; then
  echo "failed to prefetch keeper.sh $tag" >&2
  exit 1
fi
if [[ "$raw_src_hash" == sha256-* ]]; then
  new_src_hash="$raw_src_hash"
else
  new_src_hash="$(nix --extra-experimental-features nix-command hash convert --hash-algo sha256 --to sri "$raw_src_hash")"
fi

if [[ "$old_version" == "$new_version" && "$old_src_hash" == "$new_src_hash" ]]; then
  echo "keeper is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
backup="$(mktemp)"
cp "$package_file" "$backup"
trap 'cp "$backup" "$package_file"; rm -f "$backup"' ERR INT TERM

# Update version + src hash; set nodeModules hash to fake so nix reveals the real one.
OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC_HASH="$old_src_hash" NEW_SRC_HASH="$new_src_hash" \
OLD_MODULES_HASH="$old_modules_hash" FAKE_HASH="$fake_hash" \
perl -0pi -e '
  s/\n  version = "\Q$ENV{OLD_VERSION}\E";\n\n  src = fetchFromGitHub/\n  version = "$ENV{NEW_VERSION}";\n\n  src = fetchFromGitHub/ or die "failed to replace version\n";
  s/(src = fetchFromGitHub \{.*?hash = ")\Q$ENV{OLD_SRC_HASH}\E(";)/$1$ENV{NEW_SRC_HASH}$2/s or die "failed to replace source hash\n";
  s/(outputHash = ")\Q$ENV{OLD_MODULES_HASH}\E(";)/$1$ENV{FAKE_HASH}$2/ or die "failed to replace nodeModules hash\n";
' "$package_file"

set +e
build_log="$(nix build "$root#keeper-sh" --no-link 2>&1)"
build_status=$?
set -e

if [[ $build_status -eq 0 ]]; then
  echo "unexpectedly built with fake nodeModules hash" >&2
  exit 1
fi

new_modules_hash="$(grep -o 'got:[[:space:]]*sha256-[A-Za-z0-9+/=]*' <<< "$build_log" | tail -n1 | sed 's/got:[[:space:]]*//')"
if [[ -z "$new_modules_hash" ]]; then
  echo "failed to discover new nodeModules hash" >&2
  echo "$build_log" >&2
  exit 1
fi

FAKE_HASH="$fake_hash" NEW_MODULES_HASH="$new_modules_hash" \
perl -0pi -e '
  s/(outputHash = ")\Q$ENV{FAKE_HASH}\E(";)/$1$ENV{NEW_MODULES_HASH}$2/ or die "failed to replace new nodeModules hash\n";
' "$package_file"

trap - ERR INT TERM
rm -f "$backup"

printf '[{"attrPath":"keeper-sh","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

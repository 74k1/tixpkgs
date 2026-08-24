#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix git
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
pkg_file="$root/pkgs/mo/moodist/default.nix"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$pkg_file")"

release="$(curl -fsSL 'https://api.github.com/repos/remvze/moodist/releases' \
  | jq -r '[.[] | select(.prerelease == false and .draft == false)] | first')"

new_version="$(jq -r '.tag_name // empty' <<< "$release")"
new_version="${new_version#v}"

if [[ -z "$old_version" || -z "$new_version" ]]; then
  echo "failed to read current/latest Moodist version" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" ]]; then
  echo "moodist is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

rev="$(jq -r '.target_commitish // "main"' <<< "$release")"
src_url="https://github.com/remvze/moodist/archive/${rev}.tar.gz"
new_src_hash="$(nix-prefetch-url --unpack --type sha256 "$src_url" 2>/dev/null \
  | xargs nix hash convert --hash-algo sha256 --to sri)"

if [[ -z "$new_src_hash" ]]; then
  echo "failed to prefetch Moodist source" >&2
  exit 1
fi

placeholder="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
OLD_VERSION="$old_version" NEW_VERSION="$new_version" SRC_HASH="$new_src_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/(rev = \S+;[\s\S]*?hash = ")[^"]+(")/$1$ENV{SRC_HASH}$2/ or die "failed to replace src hash\n";
  s/(fetcherVersion = [0-9]+;[\s\S]*?hash = ")[^"]+(")/$1$ENV{PLACEHOLDER}$2/ or die "failed to reset pnpmDeps hash\n";
' "$pkg_file"

cd "$root"
git add -- "$pkg_file" 2>/dev/null || true

got=""
for _ in 1 2 3; do
  log="$(nix build .#moodist --no-link --print-build-logs 2>&1 || true)"
  got="$(grep -oE 'got:\s+sha256-[A-Za-z0-9+/=]+' <<< "$log" | tail -1 | awk '{print $2}')"
  [[ -n "$got" ]] && break
done

if [[ -z "$got" ]]; then
  echo "could not determine new pnpmDeps hash; fix $pkg_file by running 'nix build .#moodist' and copying the got: value" >&2
  exit 1
fi

perl -0pi -e 's/\Q$ENV{PLACEHOLDER}\E/$ENV{GOT}/' "$pkg_file"

printf '[{"attrPath":"moodist","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$pkg_file"

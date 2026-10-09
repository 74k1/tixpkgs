#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash git gawk perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/de/degoog-mcp/default.nix"
repo="https://github.com/degoog-org/mcp.git"
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
new_version="$(git ls-remote --tags --refs "$repo" \
  | awk -F/ '$NF ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ { print $NF }' \
  | sort -V \
  | tail -n1)"

if [[ -z "$old_version" || -z "$new_version" ]]; then
  echo "failed to read current or latest degoog-mcp version" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" ]]; then
  echo "degoog-mcp is already at $new_version." >&2
  printf '[]\n'
  exit 0
fi

backup="$(mktemp)"
cp "$package_file" "$backup"
restore() { cp "$backup" "$package_file"; rm -f "$backup"; }
trap 'restore' ERR INT TERM

# Bump the version and fake both the src and node_modules hashes; nix build
# reports the real ones one at a time.
OLD_VERSION="$old_version" NEW_VERSION="$new_version" FAKE_HASH="$fake_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/(\n    hash = ")[^"]+(";)/$1$ENV{FAKE_HASH}$2/ or die "failed to replace source hash\n";
  s/(outputHash = ")[^"]+(";)/$1$ENV{FAKE_HASH}$2/ or die "failed to replace node_modules hash\n";
' "$package_file"

while grep -qF "$fake_hash" "$package_file"; do
  # `|| true`: the build is expected to fail, and a failing command outside
  # an `||` list would fire the ERR trap.
  build_log="$(nix --extra-experimental-features 'nix-command flakes' build --no-link "path:$root#degoog-mcp" 2>&1)" || true
  got="$(grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' <<< "$build_log" | head -n1 | awk '{print $2}')" || true
  if [[ -z "$got" ]]; then
    echo "failed to discover a hash from the build output" >&2
    echo "$build_log" >&2
    restore
    exit 1
  fi
  FAKE_HASH="$fake_hash" GOT="$got" perl -0pi -e 's/\Q$ENV{FAKE_HASH}\E/$ENV{GOT}/' "$package_file"
done

trap - ERR INT TERM
rm -f "$backup"

printf '[{"attrPath":"degoog-mcp","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$package_file"

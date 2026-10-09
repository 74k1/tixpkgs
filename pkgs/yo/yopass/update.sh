#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
pkg_file="$root/pkgs/yo/yopass/default.nix"
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$pkg_file")"

# Get latest GitHub release tag
new_version="$(curl -fsSL 'https://api.github.com/repos/jhaals/yopass/releases/latest' | jq -r '.tag_name // empty')"
if [[ -z "$old_version" || -z "$new_version" ]]; then
  echo "failed to read current or latest yopass version" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" ]]; then
  echo "yopass is already at the latest version ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

backup="$(mktemp)"
build_log="$(mktemp)"
cp "$pkg_file" "$backup"
restore() { cp "$backup" "$pkg_file"; rm -f "$backup" "$build_log"; }
trap 'restore' ERR INT TERM

# Bump the version and fake the src, Go vendor and yarn cache hashes. Each
# rewrite is anchored on its own context, since there are several `hash =`.
OLD_VERSION="$old_version" NEW_VERSION="$new_version" FAKE="$fake_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/(rev = version;\s*hash = ")[^"]+/$1$ENV{FAKE}/ or die "failed to replace source hash\n";
  s/(vendorHash = ")[^"]+/$1$ENV{FAKE}/ or die "failed to replace vendorHash\n";
  s/(yarnLock = [^\n]*\n\s*hash = ")[^"]+/$1$ENV{FAKE}/ or die "failed to replace yarn hash\n";
' "$pkg_file"

# Build until no fake hash is left. Nix names the fixed-output derivation in
# each mismatch, so every `got:` goes to the hash it belongs to.
while grep -qF "$fake_hash" "$pkg_file"; do
  echo "building to compute hashes..." >&2
  # `|| true`: the build is expected to fail, and a failing command outside
  # an `||` list would fire the ERR trap.
  nix --extra-experimental-features 'nix-command flakes' build --keep-going --no-link "path:$root#yopass" >"$build_log" 2>&1 || true

  # The log goes through a file: env vars are capped at 128 KiB.
  BUILD_LOG="$build_log" FAKE="$fake_hash" perl -0pi -e '
    BEGIN { local $/; open my $fh, "<", $ENV{BUILD_LOG} or die; $log = <$fh>; }
    my $n = 0;
    while ($log =~ /hash mismatch in fixed-output derivation .([^\x27]+)\x27:.*?got:\s+(sha256-\S+)/sg) {
      my ($drv, $got) = ($1, $2);
      if ($drv =~ /-source\.drv$/) {
        $n += s/(rev = version;\s*hash = ")\Q$ENV{FAKE}\E/$1$got/;
      } elsif ($drv =~ /-go-modules\.drv$/) {
        $n += s/(vendorHash = ")\Q$ENV{FAKE}\E/$1$got/;
      } else {
        $n += s/(yarnLock = [^\n]*\n\s*hash = ")\Q$ENV{FAKE}\E/$1$got/;
      }
    }
    $n or die "build did not resolve any fake hash\n";
  ' "$pkg_file" || {
    cat "$build_log" >&2
    restore
    exit 1
  }
done

# Final build to verify everything works
echo "final verification build..." >&2
if ! nix --extra-experimental-features 'nix-command flakes' build --no-link "path:$root#yopass" >&2; then
  echo "final build failed, restoring $pkg_file" >&2
  restore
  exit 1
fi

trap - ERR INT TERM
rm -f "$backup" "$build_log"

printf '[{"attrPath":"yopass","oldVersion":"%s","newVersion":"%s","files":["%s"]}]\n' \
  "$old_version" "$new_version" "$pkg_file"

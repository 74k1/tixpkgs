#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq perl coreutils nix nodejs_24 prefetch-npm-deps
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
pkg_dir="$root/pkgs/gr/grimmory"
nix_file="$pkg_dir/default.nix"
lock_file="$pkg_dir/package-lock.json"

# Read current version
old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$nix_file")"
old_src_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$nix_file")"
old_npm_hash="$(perl -ne 'print $1 if /^\s*npmDepsHash = "([^"]+)";/' "$nix_file")"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_npm_hash" ]]; then
  echo "failed to read current version/hashes from $nix_file" >&2
  exit 1
fi

# Get latest release from GitHub
api="https://api.github.com/repos/grimmory-tools/grimmory/releases/latest"
release="$(curl -fsSL "$api")"
tag="$(jq -r '.tag_name // empty' <<< "$release")"

if [[ -z "$tag" ]]; then
  echo "failed to read grimmory latest release tag from $api" >&2
  exit 1
fi

if [[ "$tag" != v* ]]; then
  echo "unexpected grimmory release tag: $tag" >&2
  exit 1
fi

new_version="${tag#v}"

# Prefetch new source hash
new_src_hash="$(
  nix --extra-experimental-features nix-command store prefetch-file \
    --json --unpack --name source \
    "https://github.com/grimmory-tools/grimmory/archive/refs/tags/${tag}.tar.gz" \
    | jq -r '.hash'
)"

if [[ -z "$new_src_hash" ]]; then
  echo "failed to prefetch grimmory source for $tag" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" && "$old_src_hash" == "$new_src_hash" ]]; then
  echo "grimmory is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

echo "Updating grimmory: $old_version -> $new_version" >&2

# Update version and src hash in default.nix
OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC_HASH="$old_src_hash" NEW_SRC_HASH="$new_src_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/(src = fetchFromGitHub \{.*?hash = ")\Q$ENV{OLD_SRC_HASH}\E(";)/$1$ENV{NEW_SRC_HASH}$2/s or die "failed to replace src hash\n";
' "$nix_file"

# Download new frontend package.json and generate package-lock.json
encoded_tag="${tag//+/%2B}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

curl -fsSL -o "$tmpdir/package.json" \
  "https://raw.githubusercontent.com/grimmory-tools/grimmory/${encoded_tag}/frontend/package.json"

echo "Generating package-lock.json..." >&2
cp "$tmpdir/package.json" "$tmpdir/package-copy.json"
(
  cd "$tmpdir"
  npm install --legacy-peer-deps --package-lock-only 2>&1 | tail -1
)

# Compute new npmDepsHash
mkdir -p "$tmpdir/npm-deps-out"
prefetch-npm-deps "$tmpdir/package-lock.json" "$tmpdir/npm-deps-out" 2>&1
new_npm_hash="$(nix hash path "$tmpdir/npm-deps-out")"

if [[ -z "$new_npm_hash" ]]; then
  echo "failed to compute npmDepsHash" >&2
  exit 1
fi

echo "New npmDepsHash: $new_npm_hash" >&2

# Update package-lock.json and npmDepsHash
cp "$tmpdir/package-lock.json" "$lock_file"

OLD_NPM_HASH="$old_npm_hash" NEW_NPM_HASH="$new_npm_hash" \
perl -0pi -e '
  s/npmDepsHash = "\Q$ENV{OLD_NPM_HASH}\E";/npmDepsHash = "$ENV{NEW_NPM_HASH}";/ or die "failed to replace npmDepsHash\n";
' "$nix_file"

# Run the Gradle deps update script (this requires building with the new source first,
# which means the nix file must be valid at this point).
# The mitmCache.updateScript is built from the nix expression.
echo "Updating Gradle deps (deps.json)..." >&2

nix --extra-experimental-features nix-command build \
  "$root#grimmory.mitmCache.updateScript" --no-link 2>&1 | tail -1

update_script="$(nix --extra-experimental-features nix-command build \
  "$root#grimmory.mitmCache.updateScript" --print-out-paths --no-link 2>/dev/null)"

if [[ -x "$update_script" ]]; then
  "$update_script" 2>&1 | tail -1
  echo "Gradle deps updated." >&2
else
  echo "WARNING: Failed to run Gradle deps update script." >&2
  echo "Run: nix run .#grimmory.mitmCache.updateScript" >&2
fi

printf '[{"attrPath":"grimmory","oldVersion":"%s","newVersion":"%s","files":["%s","%s","%s"]}]\n' \
  "$old_version" "$new_version" "$nix_file" "$lock_file" "$pkg_dir/deps.json"

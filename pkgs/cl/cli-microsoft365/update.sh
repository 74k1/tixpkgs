#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl git jq perl coreutils nix prefetch-npm-deps
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
pkg_dir="$root/pkgs/cl/cli-microsoft365"
nix_file="$pkg_dir/package.nix"
lock_file="$pkg_dir/package-lock.json"
repo="pnp/cli-microsoft365"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$nix_file")"
old_src_hash="$(perl -ne 'print $1 if /^\s*hash = "([^"]+)";/' "$nix_file")"
old_npm_hash="$(perl -ne 'print $1 if /^\s*npmDepsHash = "([^"]+)";/' "$nix_file")"

if [[ -z "$old_version" || -z "$old_src_hash" || -z "$old_npm_hash" ]]; then
  echo "failed to read current version/hashes from $nix_file" >&2
  exit 1
fi

# Upstream publishes tags but no GitHub releases, so `releases/latest` is a
# 404. Sort tags by version and take the highest stable one.
tag="$(git ls-remote --tags --refs --sort=-v:refname "https://github.com/${repo}.git" 'v*' \
  | awk '{print $2}' \
  | sed 's|refs/tags/||' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | head -1)"

if [[ -z "$tag" ]]; then
  echo "failed to read cli-microsoft365 latest tag from https://github.com/${repo}" >&2
  exit 1
fi

new_version="${tag#v}"

new_src_hash="$(
  nix --extra-experimental-features nix-command store prefetch-file \
    --json --unpack --name source \
    "https://github.com/${repo}/archive/refs/tags/${tag}.tar.gz" \
    | jq -r '.hash'
)"

if [[ -z "$new_src_hash" ]]; then
  echo "failed to prefetch cli-microsoft365 source for $tag" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" && "$old_src_hash" == "$new_src_hash" ]]; then
  echo "cli-microsoft365 is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

echo "Updating cli-microsoft365: $old_version -> $new_version" >&2

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Upstream generates npm-shrinkwrap.json with npm's omit-lockfile-registry-resolved
# behaviour, so most entries carry a version but no `resolved` URL. npm ci cannot
# resolve those offline, so rebuild the lockfile with registry URLs and
# integrity hashes. Versions stay pinned exactly as upstream released them.
curl -fsSL -o "$tmpdir/npm-shrinkwrap.json" \
  "https://raw.githubusercontent.com/${repo}/${tag}/npm-shrinkwrap.json"

jq -r '
  .packages | to_entries[]
  | select(.key != "" and .value.version and (.value.resolved | not))
  | [(.value.name // (.key | split("node_modules/") | last)), .value.version]
  | @tsv
' "$tmpdir/npm-shrinkwrap.json" | sort -u > "$tmpdir/missing.tsv"

mkdir -p "$tmpdir/packuments"
printf '{}\n' > "$tmpdir/registry-map.json"

if [[ -s "$tmpdir/missing.tsv" ]]; then
  cut -f1 "$tmpdir/missing.tsv" | sort -u | sed 's|/|%2f|' > "$tmpdir/names.txt"

  xargs -P 16 -I{} curl -fsSL \
    -H 'Accept: application/vnd.npm.install-v1+json' \
    -o "$tmpdir/packuments/{}.json" \
    "https://registry.npmjs.org/{}" < "$tmpdir/names.txt"

  jq -s '
    [.[] | .name as $name | .versions | to_entries[]
      | {key: ($name + "@" + .key), value: {
          resolved: .value.dist.tarball,
          integrity: .value.dist.integrity
        }}]
    | from_entries
  ' "$tmpdir"/packuments/*.json > "$tmpdir/registry-map.json"
fi

jq --slurpfile map "$tmpdir/registry-map.json" '
  .packages |= with_entries(
    if .key != "" and .value.version and (.value.resolved | not) then
      (.value.name // (.key | split("node_modules/") | last)) as $name
      | ($name + "@" + .value.version) as $id
      | if $map[0][$id].resolved != null then
          .value.resolved = $map[0][$id].resolved
          | if $map[0][$id].integrity != null then
              .value.integrity = $map[0][$id].integrity
            else . end
        else . end
    else . end
  )
' "$tmpdir/npm-shrinkwrap.json" > "$lock_file"

missing_resolved="$(
  jq '[.packages | to_entries[]
    | select(.key != "" and .value.version and (.value.resolved | not))] | length' \
    "$lock_file"
)"
if [[ "$missing_resolved" != 0 ]]; then
  echo "failed to resolve $missing_resolved lockfile entries for $tag" >&2
  exit 1
fi

echo "Computing npmDepsHash..." >&2
mkdir -p "$tmpdir/npm-deps-out"
prefetch-npm-deps "$lock_file" "$tmpdir/npm-deps-out" >&2
new_npm_hash="$(nix hash path "$tmpdir/npm-deps-out")"

if [[ -z "$new_npm_hash" ]]; then
  echo "failed to compute npmDepsHash" >&2
  exit 1
fi

echo "New npmDepsHash: $new_npm_hash" >&2

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_SRC_HASH="$old_src_hash" NEW_SRC_HASH="$new_src_hash" \
OLD_NPM_HASH="$old_npm_hash" NEW_NPM_HASH="$new_npm_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/(src = fetchFromGitHub \{.*?hash = ")\Q$ENV{OLD_SRC_HASH}\E(";)/$1$ENV{NEW_SRC_HASH}$2/s or die "failed to replace src hash\n";
  s/npmDepsHash = "\Q$ENV{OLD_NPM_HASH}\E";/npmDepsHash = "$ENV{NEW_NPM_HASH}";/ or die "failed to replace npmDepsHash\n";
' "$nix_file"

printf '[{"attrPath":"cli-microsoft365","oldVersion":"%s","newVersion":"%s","files":["%s","%s"]}]\n' \
  "$old_version" "$new_version" "$nix_file" "$lock_file"

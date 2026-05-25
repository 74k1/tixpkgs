#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl git jq yq-go perl coreutils nix nix-prefetch-git
set -euo pipefail

root="${UPDATE_NIXPKGS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
package_file="$root/pkgs/co/commet/default.nix"
pubspec_lock_json="$root/pkgs/co/commet/pubspec.lock.json"
git_hashes_json="$root/pkgs/co/commet/git-hashes.json"
api="https://api.github.com/repos/commetchat/commet/releases/latest"

release="$(curl -fsSL "$api")"
tag="$(jq -r '.tag_name // empty' <<< "$release")"

if [[ -z "$tag" ]]; then
  echo "failed to read Commet latest release tag from $api" >&2
  exit 1
fi

if [[ "$tag" != v* ]]; then
  echo "unexpected Commet release tag: $tag" >&2
  exit 1
fi

new_version="${tag#v}"
encoded_tag="${tag//+/%2B}"

old_version="$(perl -ne 'print $1 if /^\s*version = "([^"]+)";/' "$package_file")"
old_hash="$(perl -0ne 'print $1 if /src = fetchFromGitHub \{.*?hash = "([^"]+)";/s' "$package_file")"

if [[ -z "$old_version" || -z "$old_hash" ]]; then
  echo "failed to read current version or source hash from $package_file" >&2
  exit 1
fi

new_hash="$(
  nix --extra-experimental-features nix-command store prefetch-file \
    --json --unpack --name source \
    "https://github.com/commetchat/commet/archive/refs/tags/${encoded_tag}.tar.gz" \
    | jq -r '.hash'
)"

if [[ -z "$new_hash" ]]; then
  echo "failed to prefetch Commet source for $tag" >&2
  exit 1
fi

if [[ "$old_version" == "$new_version" && "$old_hash" == "$new_hash" ]]; then
  echo "commet is already up to date ($new_version)." >&2
  printf '[]\n'
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

curl -fsSL -o "$tmpdir/pubspec.lock" \
  "https://raw.githubusercontent.com/commetchat/commet/${encoded_tag}/pubspec.lock"
yq -o=json . "$tmpdir/pubspec.lock" > "$tmpdir/pubspec.lock.json"

printf '{}\n' > "$tmpdir/git-hashes.json"
while IFS=$'\t' read -r name url rev; do
  hash="$(nix-prefetch-git --quiet --fetch-submodules --url "$url" --rev "$rev" | jq -r '.hash')"
  if [[ -z "$hash" ]]; then
    echo "failed to prefetch git dependency $name ($url @ $rev)" >&2
    exit 1
  fi
  jq -S --arg name "$name" --arg hash "$hash" '. + {($name): $hash}' \
    "$tmpdir/git-hashes.json" > "$tmpdir/git-hashes.next.json"
  mv "$tmpdir/git-hashes.next.json" "$tmpdir/git-hashes.json"
done < <(
  jq -r '.packages | to_entries[] | select(.value.source == "git") | [.key, .value.description.url, .value.description["resolved-ref"]] | @tsv' \
    "$tmpdir/pubspec.lock.json"
)

OLD_VERSION="$old_version" NEW_VERSION="$new_version" \
OLD_HASH="$old_hash" NEW_HASH="$new_hash" \
perl -0pi -e '
  s/version = "\Q$ENV{OLD_VERSION}\E";/version = "$ENV{NEW_VERSION}";/ or die "failed to replace version\n";
  s/(src = fetchFromGitHub \{.*?hash = ")\Q$ENV{OLD_HASH}\E(";)/$1$ENV{NEW_HASH}$2/s or die "failed to replace source hash\n";
' "$package_file"

cp "$tmpdir/pubspec.lock.json" "$pubspec_lock_json"
cp "$tmpdir/git-hashes.json" "$git_hashes_json"

printf '[{"attrPath":"commet","oldVersion":"%s","newVersion":"%s","files":["%s","%s","%s"]}]\n' \
  "$old_version" "$new_version" "$package_file" "$pubspec_lock_json" "$git_hashes_json"

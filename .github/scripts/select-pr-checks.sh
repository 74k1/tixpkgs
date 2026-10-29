#!/usr/bin/env bash
set -euo pipefail

# Compare the PR with its branch point, not with changes already merged to main.
git diff --name-only "${BASE_SHA}...${HEAD_SHA}" | sort -u > changed-files.txt

echo "Changed files:"
sed 's/^/  /' changed-files.txt

# Keep evaluations in the foreground so failures cannot produce a green no-op.
nix eval .#packages.x86_64-linux \
  --apply 'pkgs: builtins.attrNames pkgs' \
  --json | jq -r 'sort | .[]' > all-packages.txt
nix eval .#checks.x86_64-linux \
  --apply 'checks: builtins.attrNames checks' \
  --json | jq -r 'sort | .[] | select(startswith("module-"))' > all-module-checks.txt

mapfile -t all_packages < all-packages.txt
mapfile -t all_module_checks < all-module-checks.txt

: > all-test-files.txt
if [ -d modules/tests/nixos ]; then
  find modules/tests/nixos -type f -name '*.nix' | sort > all-test-files.txt
fi
mapfile -t all_test_files < all-test-files.txt

package_exists() {
  printf '%s\n' "${all_packages[@]}" | grep -Fx -- "$1" > /dev/null
}

module_check_exists() {
  printf '%s\n' "${all_module_checks[@]}" | grep -Fx -- "$1" > /dev/null
}

add_unique() {
  local file="$1" value="$2"
  grep -Fxq -- "$value" "$file" || printf '%s\n' "$value" >> "$file"
}

add_check_for_test_file() {
  local file="$1" relative_path check
  relative_path="${file#modules/tests/nixos/}"
  check="module-nixos-${relative_path%.nix}"
  check="${check//\//-}"
  if module_check_exists "$check"; then
    add_unique module-checks.txt "$check"
  else
    printf 'Test %s does not map to an exported check (%s).\n' "$file" "$check"
  fi
}

add_checks_for_module() {
  local module_path="$1" file relative_path found=false
  for file in "${all_test_files[@]}"; do
    relative_path="${file#modules/tests/nixos/}"
    if [ "${relative_path%/*}" = "$module_path" ]; then
      add_check_for_test_file "$file"
      found=true
    fi
  done
  if [ "$found" = false ]; then
    printf 'No module check found for %s.\n' "$module_path"
  fi
}

add_checks_for_package() {
  local package="$1" file relative_path module_path
  for file in "${all_test_files[@]}"; do
    relative_path="${file#modules/tests/nixos/}"
    module_path="${relative_path%/*}"
    if [ "${module_path##*/}" = "$package" ]; then
      add_check_for_test_file "$file"
    fi
  done

  # Companion packages whose module has a different name.
  case "$package" in
    degoog-mcp) add_checks_for_module services/degoog ;;
  esac
}

module_path_from_file() {
  local file="$1" relative_path name directory probe
  relative_path="${file#modules/nixos/}"
  name="$(basename "$relative_path")"
  directory="$(dirname "$relative_path")"

  if [ "$name" = default.nix ] || [ "$name" = README.md ]; then
    [ "$directory" = . ] || printf '%s\n' "$directory"
    return 0
  fi

  probe="$directory"
  while [ "$probe" != . ]; do
    if [ -f "modules/nixos/${probe}/default.nix" ]; then
      printf '%s\n' "$probe"
      return 0
    fi
    probe="$(dirname "$probe")"
  done

  if [[ "$name" == *.nix ]]; then
    printf '%s\n' "${relative_path%.nix}"
  fi
}

: > packages.txt
: > module-checks.txt

while IFS= read -r file; do
  case "$file" in
    pkgs/*)
      IFS=/ read -r _top _bucket package _rest <<< "$file"
      if [ -n "${package:-}" ]; then
        if [[ -z "${_rest:-}" && "$package" == *.nix ]]; then
          package="${package%.nix}"
        fi
        if package_exists "$package"; then
          add_unique packages.txt "$package"

          # Companion packages built from another package's source tree.
          case "$package" in
            enclosed)
              if package_exists enclosed-cli; then
                add_unique packages.txt enclosed-cli
              fi
              ;;
          esac
        else
          printf 'Changed package path %s maps to %s, but that package is not currently exported.\n' \
            "$file" "$package"
        fi
      fi
      ;;
    modules/nixos/*)
      module_path="$(module_path_from_file "$file")"
      if [ -n "$module_path" ]; then
        add_checks_for_module "$module_path"
      fi
      ;;
    modules/tests/nixos/*.nix)
      add_check_for_test_file "$file"
      ;;
    modules/flake/checks.nix|modules/flake/modules.nix)
      printf '%s\n' "${all_module_checks[@]}" >> module-checks.txt
      ;;
    modules/flake/packages.nix)
      printf '%s\n' "${all_packages[@]}" >> packages.txt
      ;;
    flake.nix|flake.lock)
      # Shared flake changes can affect every package and module check.
      printf '%s\n' "${all_packages[@]}" >> packages.txt
      printf '%s\n' "${all_module_checks[@]}" >> module-checks.txt
      ;;
  esac
done < changed-files.txt

sort -u -o packages.txt packages.txt
while IFS= read -r package; do
  add_checks_for_package "$package"
done < packages.txt
sed -i '/^$/d' packages.txt module-checks.txt
sort -u -o module-checks.txt module-checks.txt

# CACHIX_SKIP excludes package builds, as in the cache publication workflow.
skip_list="$(printf '%s' "${CACHIX_SKIP:-}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d' | sort -u)"
if [ -n "$skip_list" ] && [ -s packages.txt ]; then
  while IFS= read -r package; do
    if grep -Fxq -- "$package" <<< "$skip_list"; then
      echo "Skipping $package (CACHIX_SKIP)" >&2
    else
      printf '%s\n' "$package"
    fi
  done < packages.txt > packages-filtered.txt
  mv packages-filtered.txt packages.txt
fi

packages_json="$(jq -Rsc 'split("\n") | map(select(length > 0))' packages.txt)"
module_checks_json="$(jq -Rsc 'split("\n") | map(select(length > 0))' module-checks.txt)"
{
  echo "packages=${packages_json}"
  echo "module-checks=${module_checks_json}"
} >> "$GITHUB_OUTPUT"

{
  echo '## Detected PR checks'
  echo
  echo '### Packages'
  if [ -s packages.txt ]; then
    while IFS= read -r package; do printf -- "- \`%s\`\n" "$package"; done < packages.txt
  else
    echo '- none'
  fi
  echo
  echo '### Module checks'
  if [ -s module-checks.txt ]; then
    while IFS= read -r check; do printf -- "- \`%s\`\n" "$check"; done < module-checks.txt
  else
    echo '- none'
  fi
} >> "$GITHUB_STEP_SUMMARY"

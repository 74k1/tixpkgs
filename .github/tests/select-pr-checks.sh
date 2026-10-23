#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
selector="$repository_root/.github/scripts/select-pr-checks.sh"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/bin"
export PATH="$fixture/bin:$PATH"
export BASE_SHA=base-tip HEAD_SHA=pr-head
export GITHUB_OUTPUT="$fixture/output" GITHUB_STEP_SUMMARY="$fixture/summary"
export CACHIX_SKIP="" TEST_FAIL_EVAL="" TEST_FAIL_DIFF=""

# Model a PR branch behind main. A tip-to-tip diff includes unrelated updates.
cat > "$fixture/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ -n "$TEST_FAIL_DIFF" ]; then exit 1; fi
if [[ "$*" == "diff --name-only ${BASE_SHA}...${HEAD_SHA}" ]]; then
  cat branch-changes.txt
elif [[ "$*" == "diff --name-only ${BASE_SHA} ${HEAD_SHA}" ]]; then
  cat branch-changes.txt
  printf '%s\n' pkgs/fo/fogpanther/package.nix flake.lock
else
  printf 'Unexpected git arguments: %s\n' "$*" >&2
  exit 1
fi
EOF

cat > "$fixture/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" != eval ]]; then exit 1; fi
if [[ "$2" == "$TEST_FAIL_EVAL" ]]; then exit 1; fi
case "$2" in
  .#packages.x86_64-linux) cat package-inventory.json ;;
  .#checks.x86_64-linux) cat check-inventory.json ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$fixture/bin/git" "$fixture/bin/nix"
cd "$fixture"

printf '%s\n' '["wordcraft-bin","fogpanther","multi-scrobbler","degoog-mcp","trek","godap"]' > package-inventory.json
printf '%s\n' '["module-nixos-services-multi-scrobbler-basic","module-nixos-services-degoog-basic","module-nixos-services-trek-basic","module-nixos-services-trek-eval","module-nixos-services-trek-alt-basic","unrelated-check"]' > check-inventory.json

for module_path in services/multi-scrobbler services/degoog services/trek services/trek-alt; do
  mkdir -p "modules/tests/nixos/$module_path" "modules/nixos/$module_path"
  touch "modules/tests/nixos/$module_path/basic.nix" "modules/nixos/$module_path/default.nix"
done
touch modules/tests/nixos/services/trek/eval.nix

assert_selection() {
  local description="$1" expected_packages="$2" expected_checks="$3"
  shift 3
  printf '%s\n' "$@" > branch-changes.txt
  : > "$GITHUB_OUTPUT"
  : > "$GITHUB_STEP_SUMMARY"
  if ! bash "$selector" > selection.log 2>&1; then
    printf 'FAIL: %s\n' "$description" >&2
    cat selection.log >&2
    exit 1
  fi

  local actual_packages actual_checks
  actual_packages="$(grep '^packages=' "$GITHUB_OUTPUT" | cut -d= -f2-)"
  actual_checks="$(grep '^module-checks=' "$GITHUB_OUTPUT" | cut -d= -f2-)"
  if [[ "$actual_packages" != "$expected_packages" || "$actual_checks" != "$expected_checks" ]]; then
    printf 'FAIL: %s\nExpected: %s %s\nActual:   %s %s\n' \
      "$description" "$expected_packages" "$expected_checks" "$actual_packages" "$actual_checks" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$description"
}

assert_detection_failure() {
  local description="$1"
  printf '%s\n' pkgs/wo/wordcraft-bin/package.nix > branch-changes.txt
  : > "$GITHUB_OUTPUT"
  if bash "$selector" > selection.log 2>&1; then
    printf 'FAIL: %s should fail detection\n' "$description" >&2
    exit 1
  fi
  if [ -s "$GITHUB_OUTPUT" ]; then
    printf 'FAIL: %s published targets after failure\n' "$description" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$description"
}

assert_selection 'outdated PR excludes changes already merged to main' '["wordcraft-bin"]' '[]' \
  pkgs/wo/wordcraft-bin/package.nix
assert_selection 'same-name package selects its module test' '["multi-scrobbler"]' \
  '["module-nixos-services-multi-scrobbler-basic"]' pkgs/mu/multi-scrobbler/package.nix
assert_selection 'companion package selects its associated module test' '["degoog-mcp"]' \
  '["module-nixos-services-degoog-basic"]' pkgs/de/degoog-mcp/package.nix
assert_selection 'package support files select all associated checks once' '["trek"]' \
  '["module-nixos-services-trek-basic","module-nixos-services-trek-eval"]' \
  pkgs/tr/trek/package.nix pkgs/tr/trek/update.sh
assert_selection 'flat package expression is supported' '["godap"]' '[]' pkgs/go/godap.nix
assert_selection 'removed package is not built' '[]' '[]' pkgs/re/removed/package.nix
assert_selection 'root documentation selects no builds' '[]' '[]' README.md CONTRIBUTING.md
assert_selection 'empty PR diff selects no builds' '[]' '[]'
assert_selection 'flat module expression selects its checks' '[]' \
  '["module-nixos-services-degoog-basic"]' modules/nixos/services/degoog.nix
assert_selection 'module change selects only its exact checks' '[]' \
  '["module-nixos-services-trek-basic","module-nixos-services-trek-eval"]' \
  modules/nixos/services/trek/default.nix
assert_selection 'module documentation selects its checks' '[]' \
  '["module-nixos-services-degoog-basic"]' modules/nixos/services/degoog/README.md
assert_selection 'module support file selects its checks' '[]' \
  '["module-nixos-services-degoog-basic"]' modules/nixos/services/degoog/templates/config.json
assert_selection 'test change selects only that check' '[]' \
  '["module-nixos-services-trek-eval"]' modules/tests/nixos/services/trek/eval.nix
assert_selection 'removed test is not built' '[]' '[]' modules/tests/nixos/services/trek/removed.nix

all_packages='["degoog-mcp","fogpanther","godap","multi-scrobbler","trek","wordcraft-bin"]'
all_checks='["module-nixos-services-degoog-basic","module-nixos-services-multi-scrobbler-basic","module-nixos-services-trek-alt-basic","module-nixos-services-trek-basic","module-nixos-services-trek-eval"]'
associated_checks='["module-nixos-services-degoog-basic","module-nixos-services-multi-scrobbler-basic","module-nixos-services-trek-basic","module-nixos-services-trek-eval"]'
for file in flake.nix flake.lock; do
  assert_selection "$file selects the full build" "$all_packages" "$all_checks" "$file"
done
for file in modules/flake/checks.nix modules/flake/modules.nix; do
  assert_selection "$file selects every module check" '[]' "$all_checks" "$file"
done
assert_selection 'package discovery change also selects associated checks' "$all_packages" "$associated_checks" \
  modules/flake/packages.nix

export CACHIX_SKIP=' fogpanther, wordcraft-bin, , '
assert_selection 'skip list trims whitespace and excludes exact package names' '[]' '[]' \
  pkgs/fo/fogpanther/package.nix pkgs/wo/wordcraft-bin/package.nix
assert_selection 'full build still applies the package skip list' \
  '["degoog-mcp","godap","multi-scrobbler","trek"]' "$all_checks" flake.lock
export CACHIX_SKIP='wordcraft'
assert_selection 'skip list does not exclude similarly named packages' '["wordcraft-bin"]' '[]' \
  pkgs/wo/wordcraft-bin/package.nix
export CACHIX_SKIP=' , , '
assert_selection 'blank skip list does not fail detection' '["wordcraft-bin"]' '[]' \
  pkgs/wo/wordcraft-bin/package.nix
export CACHIX_SKIP=''

export TEST_FAIL_EVAL='.#packages.x86_64-linux'
assert_detection_failure 'package evaluation failure'
export TEST_FAIL_EVAL='.#checks.x86_64-linux'
assert_detection_failure 'check evaluation failure'
export TEST_FAIL_EVAL=''
export TEST_FAIL_DIFF=1
assert_detection_failure 'merge-base diff failure'
export TEST_FAIL_DIFF=''

mkdir -p modules/tests/nixos/pkgs/godap
: > modules/tests/nixos/pkgs/godap/basic.nix
jq '. + ["module-nixos-pkgs-godap-basic"]' check-inventory.json > check-inventory-updated.json
mv check-inventory-updated.json check-inventory.json
assert_selection 'package-level integration tests are selected by name' '["godap"]' \
  '["module-nixos-pkgs-godap-basic"]' pkgs/go/godap/package.nix

printf '%s\n' '[]' > package-inventory.json
printf '%s\n' '[]' > check-inventory.json
assert_selection 'empty inventories do not produce empty target names' '[]' '[]' flake.lock

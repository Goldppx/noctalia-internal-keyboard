#!/usr/bin/env sh
# Internal Keyboard - smoke test (no root, read-only).
#
#   sh tests/smoke.sh
#
# Checks the manifest, the entry wiring, the translations, the backend script and
# the README against what the community plugin repository expects.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLUGIN_DIR="$REPO_DIR/internal-keyboard"
MANIFEST="$PLUGIN_DIR/plugin.toml"
ID="goldesquemoon/internal-keyboard"
fail=0

ok() { printf '  ok    %s\n' "$1"; }
bad() {
    printf '  FAIL  %s\n' "$1" >&2
    fail=$((fail + 1))
}
check() { # description, exit code
    if [ "$2" -eq 0 ]; then ok "$1"; else bad "$1"; fi
}

printf 'layout\n'
check "plugin directory exists" "$([ -d "$PLUGIN_DIR" ] && echo 0 || echo 1)"
check "directory name matches the id" "$([ "$(basename "$PLUGIN_DIR")" = "${ID#*/}" ] && echo 0 || echo 1)"
for file in plugin.toml README.md LICENSE thumbnail.webp translations/en.json; do
    check "ships $file" "$([ -f "$PLUGIN_DIR/$file" ] && echo 0 || echo 1)"
done
check "catalog.toml lists the plugin" "$(grep -q "\"$ID\"" "$REPO_DIR/catalog.toml" && echo 0 || echo 1)"

printf 'manifest\n'
for key in id name version plugin_api author license icon description tags dependencies; do
    check "has $key" "$(grep -qE "^$key[[:space:]]*=" "$MANIFEST" && echo 0 || echo 1)"
done
check "id matches the directory" "$(grep -qE "^id[[:space:]]*=[[:space:]]*\"$ID\"" "$MANIFEST" && echo 0 || echo 1)"
check "version is MAJOR.MINOR.PATCH" "$(grep -qE '^version[[:space:]]*=[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' "$MANIFEST" && echo 0 || echo 1)"

printf 'entries\n'
for entry in service.luau shortcut.luau widget.luau; do
    check "entry file $entry exists" "$([ -f "$PLUGIN_DIR/$entry" ] && echo 0 || echo 1)"
done
ids=$(grep -E '^\s*id[[:space:]]*=' "$MANIFEST" | grep -v "^id" | sed 's/.*"\(.*\)"/\1/')
check "entry ids are unique" "$([ "$(printf '%s\n' "$ids" | sort | uniq -d)" = "" ] && echo 0 || echo 1)"

printf 'backend\n'
for script in internal-keyboard.sh setup.sh uninstall.sh; do
    check "$script is executable" "$([ -x "$PLUGIN_DIR/$script" ] && echo 0 || echo 1)"
    sh -n "$PLUGIN_DIR/$script"
    check "$script parses" $?
done
check "backend prints usage" "$("$PLUGIN_DIR/internal-keyboard.sh" --help >/dev/null 2>&1 && echo 0 || echo 1)"

printf 'translations\n'
python3 - "$PLUGIN_DIR" <<'PY'
import json, pathlib, sys, tomllib

plugin = pathlib.Path(sys.argv[1])
manifest = tomllib.loads((plugin / "plugin.toml").read_text())
en = json.loads((plugin / "translations/en.json").read_text())
zh = json.loads((plugin / "translations/zh-Hans.json").read_text())

def keys(node, prefix=""):
    found = set()
    for key, value in node.items():
        path = f"{prefix}.{key}" if prefix else key
        found |= keys(value, path) if isinstance(value, dict) else {path}
    return found

problems = []
for setting in manifest.get("setting", []):
    for field in ("label_key", "description_key"):
        path = setting.get(field)
        if path and path not in keys(en):
            problems.append(f"{field} '{path}' missing from en.json")

missing_zh = keys(en) - keys(zh)
extra_zh = keys(zh) - keys(en)
if missing_zh:
    problems.append(f"zh-Hans.json misses {sorted(missing_zh)}")
if extra_zh:
    problems.append(f"zh-Hans.json has stale {sorted(extra_zh)}")

for problem in problems:
    print(f"  FAIL  {problem}", file=sys.stderr)
if not problems:
    print("  ok    translation keys match the manifest and both locales")
sys.exit(1 if problems else 0)
PY
check "translations are consistent" $?

printf 'readme\n'
for section in "## Plugin" "## Requirements" "## Usage" "## Settings"; do
    check "has '$section'" "$(grep -qxF "$section" "$PLUGIN_DIR/README.md" && echo 0 || echo 1)"
done
check "documents the id" "$(grep -qF "\`$ID\`" "$PLUGIN_DIR/README.md" && echo 0 || echo 1)"
check "documents the shortcut entry" "$(grep -qF '`toggle`' "$PLUGIN_DIR/README.md" && echo 0 || echo 1)"

if command -v noctalia >/dev/null 2>&1; then
    printf 'noctalia lint\n'
    noctalia plugins lint "$PLUGIN_DIR" >/dev/null 2>&1
    check "noctalia plugins lint" $?
fi

if [ "$fail" -ne 0 ]; then
    printf '\n%s check(s) failed\n' "$fail" >&2
    exit 1
fi
printf '\nall checks passed\n'

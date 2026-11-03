#!/usr/bin/env sh
# Internal Keyboard - uninstaller.
#
# Disables the plugin and removes this checkout from the plugin sources.
#
#   ./uninstall.sh            # plugin + source only
#   ./uninstall.sh --purge    # also remove the backend (needs root)
set -eu

PLUGIN_ID="goldesquemoon/internal-keyboard"
SOURCE_NAME="${SOURCE_NAME:-internal-keyboard}"
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PURGE=0

for arg in "$@"; do
    case "$arg" in
    --purge) PURGE=1 ;;
    -h | --help)
        sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        printf 'uninstall: unknown option %s\n' "$arg" >&2
        exit 2
        ;;
    esac
done

if command -v noctalia >/dev/null 2>&1; then
    noctalia msg plugins disable "$PLUGIN_ID" >/dev/null 2>&1 || true
    noctalia msg plugins source remove "$SOURCE_NAME" >/dev/null 2>&1 || true
    printf 'disabled %s and removed source "%s"\n' "$PLUGIN_ID" "$SOURCE_NAME"
else
    printf 'uninstall: noctalia CLI not found, skipped plugin cleanup\n' >&2
fi

if [ "$PURGE" -eq 1 ]; then
    sudo "$REPO_DIR/internal-keyboard/uninstall.sh"
fi

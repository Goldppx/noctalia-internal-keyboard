#!/usr/bin/env sh
# Internal Keyboard - installer.
#
# Registers this checkout as a Noctalia plugin source and enables the plugin.
# The backend needs root once (a root-owned CLI, a udev rule and one sudoers
# entry), so pass --setup to run that step too, or run it yourself afterwards.
#
#   ./install.sh             # register + enable, then print next steps
#   ./install.sh --setup     # also run the root backend setup
#   SOURCE_NAME=my-plugins ./install.sh
set -eu

PLUGIN_ID="goldesquemoon/internal-keyboard"
SOURCE_NAME="${SOURCE_NAME:-internal-keyboard}"
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_DIR="$REPO_DIR/internal-keyboard"
SETUP=0

for arg in "$@"; do
    case "$arg" in
    --setup) SETUP=1 ;;
    -h | --help)
        sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        printf 'install: unknown option %s\n' "$arg" >&2
        exit 2
        ;;
    esac
done

die() {
    printf 'install: %s\n' "$*" >&2
    exit 1
}

command -v noctalia >/dev/null 2>&1 || die "noctalia CLI not found in PATH"

# 1. plugin source (idempotent)
if noctalia msg plugins source list 2>/dev/null | awk '{print $1}' | grep -qx "$SOURCE_NAME"; then
    printf 'source "%s" already registered\n' "$SOURCE_NAME"
else
    noctalia msg plugins source add "$SOURCE_NAME" path "$REPO_DIR" >/dev/null
    printf 'registered source "%s" -> %s\n' "$SOURCE_NAME" "$REPO_DIR"
fi

# 2. enable (idempotent)
noctalia msg plugins enable "$PLUGIN_ID" >/dev/null
printf 'enabled %s\n' "$PLUGIN_ID"

# 3. backend (root)
if [ "$SETUP" -eq 1 ]; then
    sudo "$PLUGIN_DIR/setup.sh"
elif [ -x /usr/local/bin/internal-keyboard ]; then
    printf 'backend: /usr/local/bin/internal-keyboard\n'
else
    printf 'backend: not installed yet\n'
fi

cat <<EOF

Next steps
  1. Backend (once, root):

       sudo $PLUGIN_DIR/setup.sh

     It lists the keyboards, installs /usr/local/bin/internal-keyboard, the udev
     rule and /etc/sudoers.d/internal-keyboard, then leaves the keyboard enabled.

  2. Control-center tile: Settings -> Control Center -> Shortcuts -> add "Internal Keyboard"
     (config.toml equivalent:)

     [[control_center.shortcuts]]
     type = "${PLUGIN_ID}:toggle"

  3. Keyboard: Settings -> Plugins -> Internal Keyboard -> "Keyboard"
     empty = the keyboard setup.sh picked; list the names with:

       internal-keyboard devices

  4. Optional keybind (nothing is bound for you):

     binds {
         Mod+Shift+K { spawn "noctalia" "msg" "plugin" "${PLUGIN_ID}:service" "all" "toggle"; }
     }

Verify
  noctalia msg plugins list | grep internal-keyboard
  internal-keyboard status
  sh $REPO_DIR/tests/smoke.sh
EOF

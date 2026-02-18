#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

if is-bool-val-false "${WEB_AUDIO:-0}"; then
    echo "ERROR: Web audio support must be enabled via the WEB_AUDIO environment variable."
    exit 1
fi

AUDACITY_CFG="$XDG_CONFIG_HOME/audacity/audacity.cfg"
mkdir -p "$(dirname "$AUDACITY_CFG")"

# Handle dark mode.
if is-bool-val-false "${DARK_MODE:-0}"; then
    if [ -f "$AUDACITY_CFG" ]; then
        sed -i '/^Theme=/d' "$AUDACITY_CFG"
    fi
else
    if [ ! -f "$AUDACITY_CFG" ]; then
        echo "[GUI]" > "$AUDACITY_CFG"
    fi

    sed -i '/^Theme=/d' "$AUDACITY_CFG"
    sed -i '/^\[GUI\]/a Theme=dark' "$AUDACITY_CFG"
fi

# vim:ft=sh:ts=4:sw=4:et:sts=4

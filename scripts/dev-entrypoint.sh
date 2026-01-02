#!/bin/bash
set -e

# Use a cache directory that appuser can write to (named volume has root ownership)
export PIP_CACHE_DIR=/app/web/.pip-cache

RELOAD_DIRS=""

APP_REQUIREMENTS_FILE="/app/web/app_requirements.txt"

# Install debugpy for debugging
pip install debugpy

# Install app requirements in editable mode if app_requirements.txt exists
if [ -f "$APP_REQUIREMENTS_FILE" ]; then
    echo "Installing app requirements in editable mode..."
    pip install --no-warn-script-location -r "$APP_REQUIREMENTS_FILE"

    # Build reload dirs from the same file
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        pkg_path="${line#-e }"
        pkg_path="${pkg_path## }"
        [ -d "$pkg_path" ] && RELOAD_DIRS="$RELOAD_DIRS --reload-dir $pkg_path"
    done < "$APP_REQUIREMENTS_FILE"
    echo "App requirements installed."
fi

# Execute the main command with reload dirs appended
exec "$@" "$RELOAD_DIRS"

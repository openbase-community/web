#!/bin/bash
set -e

# Use a cache directory that appuser can write to (named volume has root ownership)
export UV_CACHE_DIR=/app/web/.uv-cache

# Create and activate a virtual environment
VENV_DIR=/app/web/.venv
if [ ! -d "$VENV_DIR" ]; then
    uv venv --system-site-packages "$VENV_DIR"
fi
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

APP_REQUIREMENTS_FILE="/app/web/app_requirements.txt"

# Install debugpy for debugging
uv pip install debugpy

# Install app requirements in editable mode if app_requirements.txt exists
if [ -f "$APP_REQUIREMENTS_FILE" ]; then
    echo "Installing app requirements in editable mode..."
    uv pip install -r "$APP_REQUIREMENTS_FILE"
    echo "App requirements installed."
fi

# Execute the main command with reload dirs appended
exec "$@"

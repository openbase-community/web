#!/usr/bin/env bash

set -euo pipefail

# Set default values if environment variables are not provided
export PROXY_TARGET
export FRONTEND_PROXY_TARGET

echo "Configuring nginx with:"
echo "  PROXY_TARGET: $PROXY_TARGET"
echo "  FRONTEND_PROXY_TARGET: $FRONTEND_PROXY_TARGET"

# Substitute environment variables in the template
# shellcheck disable=SC2016
envsubst '${PROXY_TARGET} ${FRONTEND_PROXY_TARGET}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

echo "Generated nginx configuration:"
cat /etc/nginx/nginx.conf

# Execute the command passed to the container
exec "$@" 

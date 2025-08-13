#!/usr/bin/env bash

set -euo pipefail

# Arguments: 
# $1: IS_LOCAL boolean - controls backend API target
# $2: IS_FRONTEND_LOCAL boolean - controls frontend target
IS_LOCAL=${1:-1}
IS_FRONTEND_LOCAL=${2:-1}

if [ "$IS_LOCAL" = 1 ]; then
  export PROXY_TARGET="http://host.docker.internal:8000"
else
  export PROXY_TARGET="https://my-app.openbase.app"
fi

if [ "$IS_FRONTEND_LOCAL" = 1 ]; then
  export FRONTEND_PROXY_TARGET="http://host.docker.internal:8080"
else
  export FRONTEND_PROXY_TARGET="https://preview--my-app.lovable.app"
fi

echo "Starting nginx proxy with:"
echo "  Backend API: $PROXY_TARGET"
echo "  Frontend: $FRONTEND_PROXY_TARGET"

# Navigate to web directory and start the nginx service
cd "$(dirname "$0")/.."
docker compose up --build -d nginx

echo "Nginx proxy is running at http://localhost"
echo "To view logs: docker-compose logs -f nginx"
echo "To stop: docker-compose down" 

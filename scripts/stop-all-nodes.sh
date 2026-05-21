#!/usr/bin/env bash
# Stop and remove all running Agora containers.

set -euo pipefail

CONTAINERS=$(docker ps -a --filter name=agora_ --format '{{.Names}}' 2>/dev/null || true)

if [ -z "$CONTAINERS" ]; then
  echo "No Agora containers found."
  exit 0
fi

echo "Stopping Agora containers:"
for NAME in $CONTAINERS; do
  echo "  Stopping $NAME..."
  docker stop "$NAME" >/dev/null 2>&1 || true
  docker rm "$NAME" >/dev/null 2>&1 || true
done

echo "All Agora containers stopped and removed."

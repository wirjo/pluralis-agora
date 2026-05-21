#!/usr/bin/env bash
# Show status of all running Agora nodes.

set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Agora Node Status ==="
echo ""

# Docker containers
CONTAINERS=$(docker ps --filter name=agora_ --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true)
if [ -n "$CONTAINERS" ]; then
  echo "Running containers:"
  echo "$CONTAINERS"
else
  echo "No running Agora containers."
fi

echo ""

# Log tail (last 3 lines per GPU)
for LOG in agora_output_gpu*.log; do
  [ -f "$LOG" ] || continue
  echo "--- $LOG (last 3 lines) ---"
  tail -3 "$LOG"
  echo ""
done

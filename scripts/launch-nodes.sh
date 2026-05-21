#!/usr/bin/env bash
# Launch multiple Pluralis Agora nodes (one per GPU).
# Usage: ./scripts/launch-nodes.sh [NUM_GPUS]
#   NUM_GPUS defaults to all available GPUs detected by nvidia-smi.

set -euo pipefail
cd "$(dirname "$0")/.."

NUM_GPUS="${1:-$(nvidia-smi -L 2>/dev/null | wc -l)}"

if [ "$NUM_GPUS" -eq 0 ]; then
  echo "ERROR: No GPUs detected. Ensure NVIDIA drivers are installed and nvidia-smi works."
  exit 1
fi

echo "Launching $NUM_GPUS Agora node(s)..."
echo ""

for GPU_ID in $(seq 0 $((NUM_GPUS - 1))); do
  echo "--- Starting node on GPU $GPU_ID (port $((49200 + GPU_ID))) ---"
  python3 agora_cli.py start \
    --gpu_id "$GPU_ID" \
    --use_docker \
    --skip_input
  echo ""
done

echo "All $NUM_GPUS node(s) launched."
echo ""
echo "Useful commands:"
echo "  View logs:     tail -f agora_output_gpu<ID>.log"
echo "  Check status:  docker ps --filter name=agora_"
echo "  Stop all:      docker ps --filter name=agora_ -q | xargs docker stop && docker ps -a --filter name=agora_ -q | xargs docker rm"

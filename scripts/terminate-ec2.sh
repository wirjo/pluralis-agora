#!/usr/bin/env bash
# Terminate all Agora EC2 instances.
# Usage: ./scripts/terminate-ec2.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-ap-southeast-2}"

echo "Finding Agora EC2 instances in $REGION..."

INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Project,Values=pluralis-agora" \
    "Name=instance-state-name,Values=running,pending,stopped" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "No running Agora instances found."
  exit 0
fi

echo "Found instances: $INSTANCE_IDS"
echo ""
read -p "Terminate these instances? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region "$REGION" >/dev/null
  echo "Termination initiated."
else
  echo "Aborted."
fi

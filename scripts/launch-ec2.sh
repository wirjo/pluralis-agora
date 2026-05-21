#!/usr/bin/env bash
# Launch an EC2 GPU instance for Pluralis Agora (default: g6e.12xlarge / NVIDIA L40S, 48GB VRAM).
# Prerequisites: AWS CLI configured, appropriate IAM permissions.
#
# Usage: ./scripts/launch-ec2.sh [INSTANCE_COUNT]
#   INSTANCE_COUNT: number of instances to launch (default: 1)

set -euo pipefail

INSTANCE_TYPE="${AGORA_INSTANCE_TYPE:-g6e.12xlarge}"
INSTANCE_COUNT="${1:-1}"
AMI_ID=""  # Will auto-detect Deep Learning AMI
KEY_NAME="${AGORA_KEY_NAME:-agora-node}"
SECURITY_GROUP="${AGORA_SG:-}"
SUBNET="${AGORA_SUBNET:-}"
REGION="${AWS_DEFAULT_REGION:-ap-southeast-2}"
HF_TOKEN="${AGORA_HF_TOKEN:?Set AGORA_HF_TOKEN to your HuggingFace token}"

echo "=== Pluralis Agora EC2 Launcher ==="
echo "Instance type: $INSTANCE_TYPE"
echo "Count: $INSTANCE_COUNT"
echo "Region: $REGION"
echo ""

# Auto-detect latest Deep Learning AMI (Ubuntu, CUDA)
if [ -z "$AMI_ID" ]; then
  echo "Finding latest Deep Learning AMI..."
  AMI_ID=$(aws ec2 describe-images \
    --region "$REGION" \
    --owners amazon \
    --filters \
      "Name=name,Values=Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04)*" \
      "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text 2>/dev/null || true)

  if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
    # Fallback to standard Deep Learning AMI
    AMI_ID=$(aws ec2 describe-images \
      --region "$REGION" \
      --owners amazon \
      --filters \
        "Name=name,Values=Deep Learning AMI GPU PyTorch*Ubuntu 22.04*" \
        "Name=state,Values=available" \
      --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
      --output text 2>/dev/null || true)
  fi

  if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
    echo "ERROR: Could not find a suitable Deep Learning AMI in $REGION."
    echo "Set AMI_ID manually or check region availability."
    exit 1
  fi
  echo "Using AMI: $AMI_ID"
fi

# Create key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "Creating key pair '$KEY_NAME'..."
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --query 'KeyMaterial' \
    --output text > "$(dirname "$0")/../${KEY_NAME}.pem"
  chmod 400 "$(dirname "$0")/../${KEY_NAME}.pem"
  echo "Key saved to ${KEY_NAME}.pem"
fi

# Create security group if not provided
if [ -z "$SECURITY_GROUP" ]; then
  SG_NAME="agora-node-sg"
  SECURITY_GROUP=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NAME" \
    --region "$REGION" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)

  if [ -z "$SECURITY_GROUP" ] || [ "$SECURITY_GROUP" = "None" ]; then
    echo "Creating security group '$SG_NAME'..."
    SECURITY_GROUP=$(aws ec2 create-security-group \
      --group-name "$SG_NAME" \
      --description "Pluralis Agora node - SSH + P2P" \
      --region "$REGION" \
      --output text --query 'GroupId')

    # SSH access
    aws ec2 authorize-security-group-ingress \
      --group-id "$SECURITY_GROUP" \
      --protocol tcp --port 22 --cidr 0.0.0.0/0 \
      --region "$REGION" >/dev/null

    # Agora P2P ports (49200-49207 for up to 8 GPUs)
    aws ec2 authorize-security-group-ingress \
      --group-id "$SECURITY_GROUP" \
      --protocol tcp --port 49200-49207 --cidr 0.0.0.0/0 \
      --region "$REGION" >/dev/null

    echo "Security group created: $SECURITY_GROUP"
  else
    echo "Using existing security group: $SECURITY_GROUP"
  fi
fi

# User data script to auto-setup and run Agora
USER_DATA=$(cat <<USERDATA
#!/bin/bash
set -e

# Wait for GPU driver to be ready
until nvidia-smi >/dev/null 2>&1; do
  sleep 5
done

# Install Docker if not present
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker ubuntu
fi
systemctl enable docker
systemctl start docker

# Clone Agora
cd /home/ubuntu
git clone https://github.com/PluralisResearch/agora /home/ubuntu/agora
chown -R ubuntu:ubuntu /home/ubuntu/agora

# Create config
mkdir -p /home/ubuntu/.agora
cat > /home/ubuntu/.agora/user_config.json <<EOF
{
  "token": "${HF_TOKEN}",
  "email": "",
  "use_docker": true
}
EOF
chown -R ubuntu:ubuntu /home/ubuntu/.agora

# Pull Docker image
docker pull ghcr.io/pluralisresearch/agora:latest

# Signal ready
touch /home/ubuntu/.agora-ready
echo "Agora setup complete. Run: cd ~/agora && python3 agora_cli.py start --skip_input --use_docker"
USERDATA
)

# Launch instances
echo ""
echo "Launching $INSTANCE_COUNT x $INSTANCE_TYPE instance(s)..."

LAUNCH_ARGS=(
  --image-id "$AMI_ID"
  --instance-type "$INSTANCE_TYPE"
  --key-name "$KEY_NAME"
  --security-group-ids "$SECURITY_GROUP"
  --count "$INSTANCE_COUNT"
  --region "$REGION"
  --user-data "$USER_DATA"
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":200,"VolumeType":"gp3"}}]'
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=agora-node},{Key=Project,Value=pluralis-agora}]"
)

if [ -n "$SUBNET" ]; then
  LAUNCH_ARGS+=(--subnet-id "$SUBNET")
fi

INSTANCE_IDS=$(aws ec2 run-instances "${LAUNCH_ARGS[@]}" \
  --query 'Instances[*].InstanceId' \
  --output text)

echo "Launched instances: $INSTANCE_IDS"
echo ""

# Wait for running state
echo "Waiting for instances to reach 'running' state..."
aws ec2 wait instance-running --instance-ids $INSTANCE_IDS --region "$REGION"

# Get public IPs
echo ""
echo "=== Instance Details ==="
for ID in $INSTANCE_IDS; do
  IP=$(aws ec2 describe-instances \
    --instance-ids "$ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
  echo "  $ID: $IP"
  echo "    SSH: ssh -i ${KEY_NAME}.pem ubuntu@$IP"
  echo "    Start Agora: cd ~/agora && python3 agora_cli.py start --skip_input --use_docker"
done

echo ""
echo "=== Next Steps ==="
echo "1. Wait ~5 minutes for user-data setup to complete"
echo "2. SSH into the instance(s)"
echo "3. Check setup: cat /home/ubuntu/.agora-ready"
echo "4. Start the node: cd ~/agora && python3 agora_cli.py start --skip_input --use_docker"
echo "5. Monitor: tail -f ~/agora/agora_output_gpu0.log"

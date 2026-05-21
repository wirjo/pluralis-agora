# Pluralis Agora — Contribute GPU Nodes

Contribute your GPU to [Pluralis Research's](https://pluralis.ai/) collaborative AI training run. Agora uses Protocol Learning to train large models across distributed consumer GPUs — anyone with an RTX 4090+ can participate.

This repo provides quick-start scripts for spinning up nodes on AWS EC2 or local machines, plus an AI coding agent skill for guided setup.

> Full Agora documentation and source: [PluralisResearch/agora](https://github.com/PluralisResearch/agora)

## Quick Start

### Using an AI Coding Agent (Claude Code, Cursor, Codex)

Clone this repo and invoke the `/agora-join` skill:

```bash
git clone https://github.com/wirjo/pluralis-agora
cd pluralis-agora

# Claude Code
claude
# then type: /agora-join
```

The skill walks you through setup conversationally — collecting your HuggingFace token, detecting GPUs, configuring ports, launching the node, and monitoring startup.

For other agents (Cursor, Codex CLI), point them at `.claude/skills/agora-join/SKILL.md` for the full procedure.

### Manual Setup (Local Machine)

```bash
git clone https://github.com/wirjo/pluralis-agora
cd pluralis-agora
python3 agora_cli.py
```

The CLI handles installation, configuration, and launch interactively.

### AWS EC2

```bash
export AGORA_HF_TOKEN="hf_your_token_here"

# Launch 1 instance
./scripts/launch-ec2.sh

# Launch 3 instances
./scripts/launch-ec2.sh 3
```

See [Environment Variables](#environment-variables) for configuration options.

## Requirements

- **GPU**: NVIDIA RTX 4090 / RTX 5090 or equivalent (24GB+ VRAM, must be on Pluralis allowlist)
- **RAM**: 80GB+ per GPU
- **Disk**: 80GB+
- **Network**: 200+ Mbps stable, port 49200 open for inbound TCP
- **OS**: Linux or Windows WSL2
- **Auth**: [HuggingFace token](https://huggingface.co/settings/tokens) (no permissions needed)

> **Note**: Some datacenter GPUs (e.g. NVIDIA L4, A10G) are **not** in Pluralis's allowlist. Consumer GPUs (RTX 4090, RTX 5090) and L40S are expected to work. Check the [Pluralis Dashboard](https://agora.pluralis.ai/) for the latest supported GPU list.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/launch-ec2.sh [N]` | Launch N EC2 GPU instances with auto-setup |
| `scripts/terminate-ec2.sh` | Terminate all Agora EC2 instances |
| `scripts/launch-nodes.sh [N]` | Launch N nodes on current machine (multi-GPU) |
| `scripts/stop-all-nodes.sh` | Stop all local Docker containers |
| `scripts/status.sh` | Show running containers and recent logs |

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `AGORA_HF_TOKEN` | (required for EC2) | HuggingFace API token |
| `AWS_DEFAULT_REGION` | `ap-southeast-2` | AWS region |
| `AGORA_KEY_NAME` | `agora-node` | EC2 key pair name |
| `AGORA_SG` | (auto-created) | Security group ID |
| `AGORA_SUBNET` | (default VPC) | Subnet ID |

## How It Works

1. Your node downloads model weights and joins the P2P network
2. Pluralis's auth server verifies your GPU and token
3. Your node syncs with existing workers (can take several hours on first join)
4. Training begins — you'll see `[PROGRESS] Processed [N] batches` in logs

Track your contribution on the [Pluralis Dashboard](https://agora.pluralis.ai/).

## Important

- **`private_gpu<ID>.key`** is your node identity — contribution history persists as long as this file exists
- Nodes can join/leave at any time and rejoin with preserved history
- Run inside `tmux` or `screen` for remote/SSH sessions

## License

This repo is a fork of [PluralisResearch/agora](https://github.com/PluralisResearch/agora), distributed under the [Apache-2.0 License](LICENSE).

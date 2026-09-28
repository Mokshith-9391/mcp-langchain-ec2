#!/usr/bin/env bash
# =====================================================================
#  One-time setup on a fresh Ubuntu 22.04 / 24.04 EC2 instance.
#  Run from the project folder:   bash deploy/setup_ec2.sh
#
#  What it does:
#   1. Installs Python + venv
#   2. Creates .venv and installs requirements
#   3. Creates .env from .env.example (if missing)
#   4. Installs 3 systemd services: mcp-weather, mcp-jira, mcp-ec2
#   5. Starts them and enables them on boot
# =====================================================================
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_USER="$(whoami)"
SERVICES=(mcp-weather mcp-jira mcp-ec2)

echo "📁 Project: $APP_DIR   👤 User: $APP_USER"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "❌ This script supports Ubuntu (apt). Please launch an Ubuntu 24.04 EC2 instance."
  exit 1
fi

echo "📦 [1/5] Installing system packages..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip curl

echo "🐍 [2/5] Creating virtualenv and installing Python packages..."
cd "$APP_DIR"
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt

echo "⚙️  [3/5] Preparing .env..."
if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
  echo "   Created .env — edit it with your API keys (nano .env)."
else
  echo "   .env already exists — leaving it unchanged."
fi
mkdir -p logs

echo "🛠  [4/5] Installing systemd services..."
for svc in "${SERVICES[@]}"; do
  sed -e "s|__APP_DIR__|$APP_DIR|g" -e "s|__APP_USER__|$APP_USER|g" \
      "deploy/systemd/$svc.service" | sudo tee "/etc/systemd/system/$svc.service" >/dev/null
done
sudo systemctl daemon-reload

echo "🚀 [5/5] Starting services..."
sudo systemctl enable --now "${SERVICES[@]}"
sleep 3
for svc in "${SERVICES[@]}"; do
  printf "   %-12s %s\n" "$svc" "$(systemctl is-active "$svc")"
done

cat <<MSG

✅ Setup complete!

Next steps:
  1. nano .env                                   # add LLM key + Jira details
  2. sudo systemctl restart ${SERVICES[*]}
  3. .venv/bin/python scripts/test_servers.py    # check servers (no LLM needed)
  4. .venv/bin/python agent/agent.py             # chat with the agent

Logs:   journalctl -u mcp-weather -f
MSG

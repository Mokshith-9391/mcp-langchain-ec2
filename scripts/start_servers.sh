#!/usr/bin/env bash
# Start all 3 MCP servers in the background (for local dev / quick testing).
# On EC2 use systemd instead: see deploy/setup_ec2.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PY=".venv/bin/python"
[ -x "$PY" ] || PY="python3"
mkdir -p logs

for name in weather jira ec2; do
  if [ -f "logs/$name.pid" ] && kill -0 "$(cat logs/$name.pid)" 2>/dev/null; then
    echo "• $name already running (pid $(cat logs/$name.pid))"
    continue
  fi
  nohup "$PY" "servers/${name}_server.py" > "logs/$name.log" 2>&1 &
  echo $! > "logs/$name.pid"
  echo "• started $name (pid $!) -> logs/$name.log"
done

sleep 2
echo "Done. Test with: $PY scripts/test_servers.py"

#!/usr/bin/env bash
# Stop the servers started by start_servers.sh
cd "$(dirname "$0")/.."
for name in weather jira ec2; do
  if [ -f "logs/$name.pid" ]; then
    kill "$(cat logs/$name.pid)" 2>/dev/null && echo "• stopped $name" || echo "• $name was not running"
    rm -f "logs/$name.pid"
  fi
done

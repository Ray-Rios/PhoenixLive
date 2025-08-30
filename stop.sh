#!/bin/bash
set -e

echo "Stopping Phoenix application..."

# Kill Phoenix app if running
if pgrep -f "mix phx.server" > /dev/null; then
  pkill -f "mix phx.server"
  echo "✅ Phoenix server stopped."
else
  echo "⚠️  Phoenix server not running."
fi

# Optional: Stop local Postgres if started manually
if pgrep -x "postgres" > /dev/null; then
  pkill -x "postgres"
  echo "✅ Postgres stopped."
fi

# Optional: Stop local Redis if started manually
if pgrep -x "redis-server" > /dev/null; then
  pkill -x "redis-server"
  echo "✅ Redis stopped."
fi

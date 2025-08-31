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


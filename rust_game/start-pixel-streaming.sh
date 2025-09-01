#!/bin/bash

echo "🎮 Starting UE5 Pixel Streaming Server..."

# Start virtual display
export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x24 &

# Start window manager
fluxbox &

# Start audio system
pulseaudio --start --log-target=syslog &

# Start the pixel streaming signaling server
echo "🌐 Starting Pixel Streaming Signaling Server..."
node /app/pixel-streaming-server.js &

# Wait for signaling server to start
sleep 5

# Start the UE5 game with pixel streaming
echo "🎯 Starting UE5 Game with Pixel Streaming..."
if [ -f "/app/game/ActionRPGMultiplayerStart.exe" ]; then
    cd /app/game
    wine ActionRPGMultiplayerStart.exe -PixelStreamingURL=ws://localhost:8888 -RenderOffScreen &
else
    echo "⚠️  UE5 game executable not found. Please build and copy your packaged game to /app/game/"
    echo "📋 Instructions:"
    echo "   1. Package your UE5 project for Windows"
    echo "   2. Copy the packaged files to rust_game/Packaged/"
    echo "   3. Rebuild this Docker container"
fi

# Keep container running
echo "✅ Pixel Streaming Server ready!"
echo "🌐 Web interface available at: http://localhost:8080"
echo "🎮 Game streaming ready for browser connections"

# Wait for all background processes
wait
#!/bin/bash

# Start Pixel Streaming Service
echo "🎮 Starting UE5 Pixel Streaming Service..."

# Set environment variables
export PIXEL_STREAMING_PORT=9070
export DISPLAY=:99

# Start virtual display
echo "🖥️ Starting virtual display..."
Xvfb :99 -screen 0 1920x1080x24 &
XVFB_PID=$!

# Start window manager
echo "🪟 Starting window manager..."
fluxbox -display :99 &
FLUXBOX_PID=$!

# Start audio system
echo "🔊 Starting audio system..."
pulseaudio --start --verbose

# Start the pixel streaming signaling server
echo "🌐 Starting signaling server on port $PIXEL_STREAMING_PORT..."
node /app/pixel-streaming-server.js &
SIGNALING_PID=$!

# Start the UE5 game (if packaged game exists)
if [ -d "/app/game" ]; then
    echo "🎮 Starting UE5 game with pixel streaming..."
    cd /app/game
    
    # Look for the game executable in different possible locations
    GAME_EXECUTABLE=""
    if [ -f "Linux/ActionRPGMultiplayerStart" ]; then
        GAME_EXECUTABLE="Linux/ActionRPGMultiplayerStart"
    elif [ -f "Linux/start-game.sh" ]; then
        GAME_EXECUTABLE="Linux/start-game.sh"
    elif [ -f "ActionRPGMultiplayerStart.sh" ]; then
        GAME_EXECUTABLE="ActionRPGMultiplayerStart.sh"
    elif [ -f "ActionRPGMultiplayerStart" ]; then
        GAME_EXECUTABLE="ActionRPGMultiplayerStart"
    fi
    
    if [ -n "$GAME_EXECUTABLE" ]; then
        echo "🚀 Found game executable: $GAME_EXECUTABLE"
        ./$GAME_EXECUTABLE -RenderOffScreen -PixelStreamingURL=ws://localhost:$PIXEL_STREAMING_PORT &
        GAME_PID=$!
    else
        echo "⚠️ No game executable found in /app/game"
        echo "📋 Available files:"
        find /app/game -type f -executable 2>/dev/null || echo "No executable files found"
    fi
else
    echo "⚠️ No packaged game found at /app/game"
    echo "📝 To add your game:"
    echo "   1. Package your UE5 project for Linux"
    echo "   2. Copy the packaged files to /app/game/"
    echo "   3. Restart this container"
fi

# Function to cleanup on exit
cleanup() {
    echo "🛑 Shutting down services..."
    kill $SIGNALING_PID 2>/dev/null
    kill $GAME_PID 2>/dev/null
    kill $FLUXBOX_PID 2>/dev/null
    kill $XVFB_PID 2>/dev/null
    pulseaudio --kill
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

echo "✅ Pixel Streaming Service is running!"
echo "🌐 Access the stream at: http://localhost:$PIXEL_STREAMING_PORT"
echo "🎮 Game server integration ready"

# Keep the script running
wait
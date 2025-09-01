# UE5 Project Build Instructions

## Quick Build Commands

### Option 1: PowerShell Script (Recommended)
```powershell
cd rust_game
.\build.ps1
```

### Option 2: Direct Docker Command
```bash
# Build the Docker image first
docker build -f Dockerfile.ue5-builder -t ue5-builder .

# Run the build
docker run --rm \
  -v "${PWD}:/project" \
  -v "ue5_build_cache:/tmp/ue5_cache" \
  -e PROJECT_NAME="ActionRPGMultiplayerStart" \
  -e BUILD_PLATFORM="Win64" \
  -e BUILD_CONFIG="Shipping" \
  ue5-builder
```

### Option 3: Docker Compose
```bash
# Build using docker-compose
docker-compose -f docker-compose.build.yml run ue5-builder

# Or use the pre-built container
docker-compose -f docker-compose.build.yml run ue5-prebuilt ./build-project.sh
```

## What the Build Does

1. **Creates Docker Container** with UE5 build environment
2. **Compiles Your Project** for Windows 64-bit
3. **Packages the Game** into deployable format
4. **Outputs to** `./Packaged/` directory
5. **Prepares for** both desktop and pixel streaming deployment

## Build Output

After successful build, you'll have:
```
rust_game/
├── Packaged/
│   └── ActionRPGMultiplayerStart/
│       ├── Binaries/Win64/
│       │   └── ActionRPGMultiplayerStart.exe  # Your game!
│       ├── Content/
│       └── Engine/
├── BuildLogs/
│   ├── docker-build.log
│   └── ue5-build.log
```

## Deployment Options

### Desktop Distribution
```bash
# Zip the packaged game for distribution
cd Packaged
zip -r ActionRPGMultiplayerStart-Win64.zip ActionRPGMultiplayerStart/
```

### Pixel Streaming Setup
```bash
# Copy to pixel streaming container
cp -r Packaged/ActionRPGMultiplayerStart pixel-streaming-game/

# Start pixel streaming service
docker-compose up pixel_streaming
```

### Game Server Integration
```bash
# Start the complete MMO stack
docker-compose up -d
```

## Troubleshooting

### Build Fails
1. Check `BuildLogs/ue5-build.log` for errors
2. Ensure Docker has enough memory (8GB+ recommended)
3. Verify project file exists: `ActionRPGMultiplayerStart.uproject`

### Docker Issues
```bash
# Clean Docker cache if needed
docker system prune -f
docker volume prune -f

# Rebuild container
docker build --no-cache -f Dockerfile.ue5-builder -t ue5-builder .
```

### UE5 Source Issues
If using source build, you need Epic Games account:
1. Link GitHub account to Epic Games account
2. Accept UE5 license agreement
3. Use personal access token for GitHub

## Alternative: Manual UE5 Build

If Docker build fails, you can build manually:

1. **Open UE5 Editor**
2. **Open Project**: `ActionRPGMultiplayerStart.uproject`
3. **Package Project**: 
   - File → Package Project → Windows (64-bit)
   - Choose output folder: `./Packaged/`
4. **Wait for Build** (can take 30+ minutes)
5. **Test Executable**: `./Packaged/ActionRPGMultiplayerStart.exe`

## Performance Tips

- **Use SSD** for faster builds
- **Allocate 8GB+ RAM** to Docker
- **Close other applications** during build
- **Use incremental builds** when possible
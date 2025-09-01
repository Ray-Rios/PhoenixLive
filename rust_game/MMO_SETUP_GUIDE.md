# MMO System Setup Guide

## 🚀 Quick Start

### 1. Compile the Project
1. **Close UE5 Editor** if it's open
2. **Right-click** on `ActionRPGMultiplayerStart.uproject`
3. Select **"Generate Visual Studio project files"**
4. **Open** the generated `.sln` file in Visual Studio
5. **Build** the project (Ctrl+Shift+B)

### 2. Open UE5 Editor
1. **Open** `ActionRPGMultiplayerStart.uproject` in UE5
2. The project should now use the **MMO Game Mode** automatically

### 3. Test the Connection
1. **Play** the game (click Play button in editor)
2. **Check Output Log** (Window → Developer Tools → Output Log)
3. **Look for these messages**:
   ```
   🎮 MMO Game Mode initialized with MMO Player Controller
   🌟 MMO Game Mode started - Ready for players!
   👤 MMO Player joined! Total players: 1
   🎮 MMO Player Controller initialized with Game Server Manager
   🔄 Connecting to MMO server...
   ✅ Connected! Session ID: [some-id]
   ```

### 4. Verify Connection
**In PowerShell/Command Prompt:**
```bash
curl http://localhost:9069/game/players
```

**Should return:**
```json
{"count":1,"players":[{"session_id":"...","x":0,"y":0,"z":0,"health":100,"level":1,"score":0,"experience":0}]}
```

## 🔧 Troubleshooting

### No Connection Messages
1. **Check Game Mode**: Make sure the game is using MMO Game Mode
2. **Check Services**: Ensure Docker services are running:
   ```bash
   docker-compose ps
   ```
3. **Check Game Service**: Test the health endpoint:
   ```bash
   curl http://localhost:9069/health
   ```

### Compilation Errors
1. **Regenerate Project Files**: Right-click `.uproject` → Generate Visual Studio project files
2. **Clean Build**: Build → Clean Solution, then Build → Rebuild Solution
3. **Check Dependencies**: Make sure HTTP module is included in build file

### Connection Fails
1. **Check Server URL**: Default is `http://localhost:9069`
2. **Check Firewall**: Make sure port 9069 is accessible
3. **Check Docker**: Ensure game_service container is running

## 🎮 Manual Testing

If auto-connection doesn't work, you can test manually:

1. **In UE5 Editor**: 
   - Open **World Settings**
   - Find **Game Mode Override**
   - Set to **MMO Game Mode**

2. **In Blueprint**:
   - Get reference to **MMO Player Controller**
   - Call **Connect To MMO Server**

3. **Force Connection**:
   - In Game Mode, call **Test MMO Connection** function

## 📊 Monitoring

### UE5 Output Log Messages
- `🎮` = MMO system initialization
- `🔄` = Connection attempts  
- `✅` = Successful operations
- `❌` = Errors
- `📍` = Position updates
- `👥` = Player count updates

### Server Endpoints
- `GET /health` - Check if game service is running
- `GET /game/players` - See connected players
- `POST /game/session` - Create new player session
- `PUT /game/session/{id}/update` - Update player data

## 🎯 Expected Behavior

When working correctly:
1. **Game starts** → MMO Game Mode loads
2. **Player spawns** → MMO Player Controller created
3. **Auto-connection** → Connects to game service within 1 second
4. **Position sync** → Updates every 5 seconds
5. **Stats sync** → Updates when health/level/score changes
6. **Player list** → Updates every 10 seconds

## 🐛 Debug Commands

### In UE5 Console (` key):
```
showdebug log
```

### In PowerShell:
```bash
# Check all services
docker-compose ps

# Check game service logs
docker-compose logs game_service

# Test API directly
curl http://localhost:9069/game/players
curl http://localhost:9069/health

# Restart services if needed
docker-compose restart game_service
```

## ✅ Success Indicators

You'll know it's working when:
- ✅ UE5 shows connection messages in Output Log
- ✅ `curl http://localhost:9069/game/players` shows your player
- ✅ Player count increases when you play
- ✅ Position updates appear in logs
- ✅ No error messages in red

The system is designed to be **automatic** - just play the game and it should connect!
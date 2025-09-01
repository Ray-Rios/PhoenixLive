# UE5 MMO Integration Guide

## Server Endpoints
Your game server is running at: `http://localhost:9069`

### Available API Endpoints:
- `GET /health` - Check server status
- `POST /game/session` - Create player session
- `GET /game/session/{id}` - Get player data
- `PUT /game/session/{id}/update` - Update player position/stats
- `GET /game/players` - List all online players

## UE5 Blueprint Setup

### 1. Enable HTTP Plugin
1. Go to **Edit → Plugins**
2. Search for "HTTP"
3. Enable **HTTP** plugin
4. Restart UE5

### 2. Create Game Server Manager Blueprint

Create a new Blueprint Class → Actor → Name it `BP_GameServerManager`

#### Variables to Add:
- `ServerURL` (String) = "http://localhost:9069"
- `SessionID` (String)
- `PlayerID` (String) 
- `IsConnected` (Boolean)

#### Functions to Create:

**ConnectToServer:**
```
1. HTTP Request Node
   - URL: ServerURL + "/game/session"
   - Verb: POST
   - Content Type: application/json
   - Content: {"user_id": "550e8400-e29b-41d4-a716-446655440000"}

2. On Response Received:
   - Parse JSON Response
   - Set SessionID from response.id
   - Set IsConnected = true
   - Print "Connected to MMO Server!"
```

**UpdatePlayerPosition:**
```
1. HTTP Request Node
   - URL: ServerURL + "/game/session/" + SessionID + "/update"
   - Verb: PUT
   - Content Type: application/json
   - Content: {
       "player_x": PlayerLocation.X,
       "player_y": PlayerLocation.Y, 
       "player_z": PlayerLocation.Z,
       "health": CurrentHealth
     }
```

**GetOnlinePlayers:**
```
1. HTTP Request Node
   - URL: ServerURL + "/game/players"
   - Verb: GET

2. On Response Received:
   - Parse JSON Array
   - Update UI with player list
```

### 3. Integration in Player Controller

In your Player Controller Blueprint:

**BeginPlay:**
1. Spawn `BP_GameServerManager`
2. Call `ConnectToServer`

**Tick (every 5 seconds):**
1. Call `UpdatePlayerPosition`
2. Call `GetOnlinePlayers`

### 4. UI Integration

Create a Widget Blueprint for MMO features:
- Player list display
- Server status indicator
- Chat system (future)
- Guild management (future)

## Testing the Connection

1. **Package your UE5 game:**
   - File → Package Project → Windows (64-bit)
   - Choose output folder (e.g., `C:\UE5Games\ActionRPG\`)

2. **Run the packaged game**
3. **Check the web dashboard** at http://localhost:9069
4. **Monitor Phoenix dashboard** at http://localhost:4000

## Web Dashboard Features

The Phoenix web app provides:
- Player management
- Server statistics  
- Game analytics
- Admin controls
- Real-time monitoring

## Architecture Overview

```
[UE5 Desktop Client] ←→ [Rust Game Server:9069] ←→ [CockroachDB]
                                ↕
                    [Phoenix Web Dashboard:4000] ←→ [Redis Cache]
```

## Next Development Steps

1. **Multiplayer Sync:** Add real-time player position sync
2. **Chat System:** Implement in-game chat via WebSockets
3. **Guilds/Parties:** Add social features through web dashboard
4. **Inventory Sync:** Sync player items between client and server
5. **Leaderboards:** Display rankings on web dashboard
6. **Admin Tools:** Manage players through Phoenix interface

## Troubleshooting

**Connection Issues:**
- Ensure game server is running: `docker-compose up -d`
- Check firewall settings for port 9069
- Verify UE5 HTTP plugin is enabled

**Performance:**
- Reduce update frequency for position sync
- Implement delta compression for large data
- Use WebSockets for real-time features

**Development:**
- Use UE5 Blueprint debugging tools
- Monitor server logs: `docker-compose logs game_service`
- Check Phoenix logs: `docker-compose logs web`
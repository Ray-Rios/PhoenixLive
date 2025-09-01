use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Method, Request, Response, Server, StatusCode};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::convert::Infallible;
use std::sync::Arc;
use tokio::sync::Mutex;
use uuid::Uuid;

#[derive(Clone, Serialize, Deserialize)]
struct GameSession {
    id: Uuid,
    user_id: Uuid,
    session_token: String,
    player_x: f64,
    player_y: f64,
    player_z: f64,
    rotation_x: f64,
    rotation_y: f64,
    rotation_z: f64,
    health: i32,
    score: i32,
    level: i32,
    experience: i32,
    is_active: bool,
}

#[derive(Serialize, Deserialize)]
struct CreateSessionRequest {
    user_id: Uuid,
}

#[derive(Serialize, Deserialize)]
struct UpdateSessionRequest {
    player_x: Option<f64>,
    player_y: Option<f64>,
    player_z: Option<f64>,
    rotation_x: Option<f64>,
    rotation_y: Option<f64>,
    rotation_z: Option<f64>,
    health: Option<i32>,
    score: Option<i32>,
    level: Option<i32>,
    experience: Option<i32>,
}

#[derive(Serialize, Deserialize)]
struct CreateSessionFromAuth {
    user_id: String,
    email: String,
    name: Option<String>,
    game_token: String,
    is_admin: bool,
}

type Sessions = Arc<Mutex<HashMap<Uuid, GameSession>>>;

async fn handle_request(req: Request<Body>, sessions: Sessions) -> Result<Response<Body>, Infallible> {
    let response = match (req.method(), req.uri().path()) {
        (&Method::GET, "/health") => {
            let json = serde_json::json!({"status": "UE5 MMO Game Service is running"});
            Response::builder()
                .status(StatusCode::OK)
                .header("content-type", "application/json")
                .header("access-control-allow-origin", "*")
                .body(Body::from(json.to_string()))
                .unwrap()
        }
        (&Method::GET, "/api/players") => {
            let sessions_lock = sessions.lock().await;
            let active_players: Vec<&GameSession> = sessions_lock
                .values()
                .filter(|s| s.is_active)
                .collect();
            
            let response_data = serde_json::json!({
                "count": active_players.len(),
                "players": active_players
            });

            Response::builder()
                .status(StatusCode::OK)
                .header("content-type", "application/json")
                .header("access-control-allow-origin", "*")
                .body(Body::from(response_data.to_string()))
                .unwrap()
        }
        (&Method::GET, "/") => {
            let html = r#"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>UE5 MMO Game Service</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            margin: 0;
            padding: 20px;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 40px;
            box-shadow: 0 15px 35px rgba(0,0,0,0.3);
            max-width: 800px;
            text-align: center;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        h1 { color: #fff; margin-bottom: 20px; font-size: 2.5em; }
        .status { color: #4CAF50; font-weight: bold; margin: 20px 0; font-size: 1.2em; }
        .info { 
            background: rgba(255, 255, 255, 0.1); 
            padding: 20px; 
            border-radius: 10px; 
            margin: 20px 0; 
            text-align: left; 
        }
        .api-endpoint { 
            background: rgba(0, 0, 0, 0.3); 
            padding: 12px; 
            border-radius: 5px; 
            font-family: 'Courier New', monospace; 
            margin: 8px 0; 
            color: #E0E0E0;
        }
        .game-area {
            border: 2px dashed rgba(255, 255, 255, 0.3);
            padding: 40px;
            margin: 20px 0;
            border-radius: 10px;
            background: rgba(255, 255, 255, 0.05);
        }
        button {
            background: linear-gradient(45deg, #FF6B6B, #4ECDC4);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 25px;
            cursor: pointer;
            margin: 8px;
            font-weight: bold;
            transition: transform 0.2s;
        }
        button:hover { 
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.3);
        }
        .ue5-logo {
            font-size: 3em;
            margin-bottom: 10px;
        }
        .download-section {
            background: rgba(255, 255, 255, 0.1);
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="ue5-logo">🎮</div>
        <h1>UE5 Action RPG MMO</h1>
        <div class="status">✅ Game Server Running on Port 8080</div>
        
        <div class="game-area">
            <h3>🏰 Action RPG Multiplayer Game</h3>
            <p>This is the backend service for the UE5 Action RPG MMO game.</p>
            <p><strong>Game Project:</strong> ActionRPGMultiplayerStart (UE5.4)</p>
        </div>

        <div class="download-section">
            <h3>🎮 How to Play</h3>
            
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 20px 0;">
                <div style="background: rgba(76, 175, 80, 0.1); padding: 15px; border-radius: 8px; border-left: 4px solid #4CAF50;">
                    <h4>🖥️ Desktop Client (Best Performance)</h4>
                    <ol style="text-align: left; font-size: 0.9em;">
                        <li>Open ActionRPGMultiplayerStart.uproject in UE5.4</li>
                        <li>Package for Windows (64-bit)</li>
                        <li>Run the packaged .exe file</li>
                        <li>Automatic server connection</li>
                    </ol>
                </div>
                
                <div style="background: rgba(33, 150, 243, 0.1); padding: 15px; border-radius: 8px; border-left: 4px solid #2196F3;">
                    <h4>🌐 Browser Play (Instant Access)</h4>
                    <p style="text-align: left; font-size: 0.9em; margin-bottom: 10px;">
                        Play directly in your web browser with no downloads required!
                    </p>
                    <a href="http://localhost:9070" target="_blank" 
                       style="background: #2196F3; color: white; padding: 8px 16px; border-radius: 20px; text-decoration: none; font-weight: bold;">
                        🎮 Play in Browser
                    </a>
                </div>
            </div>
        </div>

        <div class="info">
            <h3>🔌 MMO API Endpoints:</h3>
            <div class="api-endpoint">GET /health - Server health check</div>
            <div class="api-endpoint">POST /game/session - Create player session</div>
            <div class="api-endpoint">GET /game/session/{id} - Get player data</div>
            <div class="api-endpoint">PUT /game/session/{id}/update - Update player state</div>
            <div class="api-endpoint">GET /game/players - List online players</div>
        </div>

        <button onclick="testAPI()">🔍 Test Server</button>
        <button onclick="createSession()">👤 Create Player</button>
        <button onclick="listPlayers()">👥 List Players</button>
        
        <div style="margin: 20px 0; padding: 20px; background: rgba(33, 150, 243, 0.1); border-radius: 10px; border-left: 4px solid #2196F3;">
            <h4>🔐 Unified Authentication</h4>
            <p style="text-align: left; font-size: 0.9em; margin-bottom: 10px;">
                To play with your Phoenix account, login through the main web app first, then return here.
            </p>
            <a href="http://localhost:4000/login" target="_blank" 
               style="background: #2196F3; color: white; padding: 8px 16px; border-radius: 20px; text-decoration: none; font-weight: bold;">
                🚀 Login to Phoenix
            </a>
        </div>
        
        <div id="result" style="margin-top: 20px; padding: 15px; border-radius: 5px;"></div>
    </div>

    <script>
        async function testAPI() {
            try {
                const response = await fetch('/health');
                const data = await response.json();
                document.getElementById('result').innerHTML = 
                    `<div style="background: rgba(76, 175, 80, 0.2); color: #4CAF50; padding: 10px; border-radius: 5px;">
                        ✅ Server Status: ${data.status}
                    </div>`;
            } catch (error) {
                document.getElementById('result').innerHTML = 
                    `<div style="background: rgba(244, 67, 54, 0.2); color: #F44336; padding: 10px; border-radius: 5px;">
                        ❌ Connection Error: ${error.message}
                    </div>`;
            }
        }

        async function createSession() {
            try {
                const response = await fetch('/game/session', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ user_id: '550e8400-e29b-41d4-a716-446655440000' })
                });
                const data = await response.json();
                document.getElementById('result').innerHTML = 
                    `<div style="background: rgba(76, 175, 80, 0.2); color: #4CAF50; padding: 10px; border-radius: 5px;">
                        ✅ Player Session Created!<br>
                        🆔 Session ID: ${data.id}<br>
                        🎯 Health: ${data.health} | Level: ${data.level}
                    </div>`;
            } catch (error) {
                document.getElementById('result').innerHTML = 
                    `<div style="background: rgba(244, 67, 54, 0.2); color: #F44336; padding: 10px; border-radius: 5px;">
                        ❌ Session Error: ${error.message}
                    </div>`;
            }
        }

        async function listPlayers() {
            try {
                const response = await fetch('/game/players');
                const data = await response.json();
                document.getElementById('result').innerHTML = 
                    `<div style="background: rgba(33, 150, 243, 0.2); color: #2196F3; padding: 10px; border-radius: 5px;">
                        👥 Online Players: ${data.count}<br>
                        ${data.players.map(p => `🎮 Level ${p.level} Player (Health: ${p.health})`).join('<br>')}
                    </div>`;
            } catch (error) {
                document.getElementById('result').innerHTML = 
                    `<div style="background: rgba(244, 67, 54, 0.2); color: #F44336; padding: 10px; border-radius: 5px;">
                        ❌ Players Error: ${error.message}
                    </div>`;
            }
        }


    </script>
</body>
</html>
            "#;
            
            Response::builder()
                .status(StatusCode::OK)
                .header("content-type", "text/html")
                .header("access-control-allow-origin", "*")
                .body(Body::from(html))
                .unwrap()
        }
        (&Method::POST, "/auth/create_session") => {
            let body_bytes = hyper::body::to_bytes(req.into_body()).await.unwrap();
            match serde_json::from_slice::<CreateSessionFromAuth>(&body_bytes) {
                Ok(auth_data) => {
                    let session_id = Uuid::new_v4();
                    let user_uuid = Uuid::parse_str(&auth_data.user_id).unwrap_or_else(|_| Uuid::new_v4());
                    
                    let session = GameSession {
                        id: session_id,
                        user_id: user_uuid,
                        session_token: auth_data.game_token,
                        player_x: 0.0,
                        player_y: 0.0,
                        player_z: 0.0,
                        rotation_x: 0.0,
                        rotation_y: 0.0,
                        rotation_z: 0.0,
                        health: 100,
                        score: 0,
                        level: 1,
                        experience: 0,
                        is_active: true,
                    };

                    sessions.lock().await.insert(session_id, session.clone());
                    println!("Created game session {} for authenticated user {}", session_id, auth_data.email);

                    let response_data = serde_json::json!({
                        "success": true,
                        "session": session
                    });

                    Response::builder()
                        .status(StatusCode::OK)
                        .header("content-type", "application/json")
                        .header("access-control-allow-origin", "*")
                        .body(Body::from(response_data.to_string()))
                        .unwrap()
                }
                Err(_) => {
                    Response::builder()
                        .status(StatusCode::BAD_REQUEST)
                        .header("access-control-allow-origin", "*")
                        .body(Body::from("Invalid JSON"))
                        .unwrap()
                }
            }
        }
        (&Method::POST, "/game/session") => {
            let body_bytes = hyper::body::to_bytes(req.into_body()).await.unwrap();
            match serde_json::from_slice::<CreateSessionRequest>(&body_bytes) {
                Ok(payload) => {
                    let session_id = Uuid::new_v4();
                    let session_token = Uuid::new_v4().to_string();

                    let session = GameSession {
                        id: session_id,
                        user_id: payload.user_id,
                        session_token,
                        player_x: 0.0,
                        player_y: 0.0,
                        player_z: 0.0,
                        rotation_x: 0.0,
                        rotation_y: 0.0,
                        rotation_z: 0.0,
                        health: 100,
                        score: 0,
                        level: 1,
                        experience: 0,
                        is_active: true,
                    };

                    sessions.lock().await.insert(session_id, session.clone());
                    println!("Created MMO session {} for user {}", session_id, payload.user_id);

                    Response::builder()
                        .status(StatusCode::OK)
                        .header("content-type", "application/json")
                        .header("access-control-allow-origin", "*")
                        .body(Body::from(serde_json::to_string(&session).unwrap()))
                        .unwrap()
                }
                Err(_) => {
                    Response::builder()
                        .status(StatusCode::BAD_REQUEST)
                        .header("access-control-allow-origin", "*")
                        .body(Body::from("Invalid JSON"))
                        .unwrap()
                }
            }
        }
        (&Method::GET, "/game/players") => {
            let sessions_lock = sessions.lock().await;
            let active_players: Vec<&GameSession> = sessions_lock
                .values()
                .filter(|s| s.is_active)
                .collect();
            
            let response_data = serde_json::json!({
                "count": active_players.len(),
                "players": active_players
            });

            Response::builder()
                .status(StatusCode::OK)
                .header("content-type", "application/json")
                .header("access-control-allow-origin", "*")
                .body(Body::from(response_data.to_string()))
                .unwrap()
        }
        (&Method::GET, path) if path.starts_with("/game/session/") => {
            let session_id_str = path.strip_prefix("/game/session/").unwrap();
            match Uuid::parse_str(session_id_str) {
                Ok(session_id) => {
                    let sessions_lock = sessions.lock().await;
                    match sessions_lock.get(&session_id) {
                        Some(session) if session.is_active => {
                            Response::builder()
                                .status(StatusCode::OK)
                                .header("content-type", "application/json")
                                .header("access-control-allow-origin", "*")
                                .body(Body::from(serde_json::to_string(session).unwrap()))
                                .unwrap()
                        }
                        _ => {
                            Response::builder()
                                .status(StatusCode::NOT_FOUND)
                                .header("access-control-allow-origin", "*")
                                .body(Body::from("Session not found"))
                                .unwrap()
                        }
                    }
                }
                Err(_) => {
                    Response::builder()
                        .status(StatusCode::BAD_REQUEST)
                        .header("access-control-allow-origin", "*")
                        .body(Body::from("Invalid session ID"))
                        .unwrap()
                }
            }
        }
        (&Method::PUT, path) if path.contains("/update") => {
            let parts: Vec<&str> = path.split('/').collect();
            if parts.len() >= 4 && parts[1] == "game" && parts[2] == "session" && parts[4] == "update" {
                match Uuid::parse_str(parts[3]) {
                    Ok(session_id) => {
                        let body_bytes = hyper::body::to_bytes(req.into_body()).await.unwrap();
                        match serde_json::from_slice::<UpdateSessionRequest>(&body_bytes) {
                            Ok(payload) => {
                                let mut sessions_lock = sessions.lock().await;
                                match sessions_lock.get_mut(&session_id) {
                                    Some(session) if session.is_active => {
                                        if let Some(x) = payload.player_x { session.player_x = x; }
                                        if let Some(y) = payload.player_y { session.player_y = y; }
                                        if let Some(z) = payload.player_z { session.player_z = z; }
                                        if let Some(rx) = payload.rotation_x { session.rotation_x = rx; }
                                        if let Some(ry) = payload.rotation_y { session.rotation_y = ry; }
                                        if let Some(rz) = payload.rotation_z { session.rotation_z = rz; }
                                        if let Some(health) = payload.health { session.health = health; }
                                        if let Some(score) = payload.score { session.score = score; }
                                        if let Some(level) = payload.level { session.level = level; }
                                        if let Some(exp) = payload.experience { session.experience = exp; }

                                        println!("Updated MMO session {}", session_id);
                                        Response::builder()
                                            .status(StatusCode::OK)
                                            .header("content-type", "application/json")
                                            .header("access-control-allow-origin", "*")
                                            .body(Body::from(serde_json::to_string(session).unwrap()))
                                            .unwrap()
                                    }
                                    _ => {
                                        Response::builder()
                                            .status(StatusCode::NOT_FOUND)
                                            .header("access-control-allow-origin", "*")
                                            .body(Body::from("Session not found"))
                                            .unwrap()
                                    }
                                }
                            }
                            Err(_) => {
                                Response::builder()
                                    .status(StatusCode::BAD_REQUEST)
                                    .header("access-control-allow-origin", "*")
                                    .body(Body::from("Invalid JSON"))
                                    .unwrap()
                            }
                        }
                    }
                    Err(_) => {
                        Response::builder()
                            .status(StatusCode::BAD_REQUEST)
                            .header("access-control-allow-origin", "*")
                            .body(Body::from("Invalid session ID"))
                            .unwrap()
                    }
                }
            } else {
                Response::builder()
                    .status(StatusCode::NOT_FOUND)
                    .header("access-control-allow-origin", "*")
                    .body(Body::from("Not found"))
                    .unwrap()
            }
        }
        (&Method::OPTIONS, _) => {
            Response::builder()
                .status(StatusCode::OK)
                .header("access-control-allow-origin", "*")
                .header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
                .header("access-control-allow-headers", "content-type")
                .body(Body::empty())
                .unwrap()
        }
        _ => {
            Response::builder()
                .status(StatusCode::NOT_FOUND)
                .header("access-control-allow-origin", "*")
                .body(Body::from("Endpoint not found"))
                .unwrap()
        }
    };

    Ok(response)
}

#[tokio::main]
async fn main() {
    let sessions: Sessions = Arc::new(Mutex::new(HashMap::new()));

    let make_svc = make_service_fn(move |_conn| {
        let sessions = sessions.clone();
        async move {
            Ok::<_, Infallible>(service_fn(move |req| {
                handle_request(req, sessions.clone())
            }))
        }
    });

    let port = std::env::var("GAME_SERVICE_PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse::<u16>()
        .unwrap_or(8080);

    let addr = ([0, 0, 0, 0], port).into();
    let server = Server::bind(&addr).serve(make_svc);

    println!("🎮 UE5 MMO Game Service starting on port {}", port);
    println!("🏰 ActionRPG Multiplayer Backend Ready!");

    if let Err(e) = server.await {
        eprintln!("Server error: {}", e);
    }
}
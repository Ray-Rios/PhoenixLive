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

type Sessions = Arc<Mutex<HashMap<Uuid, GameSession>>>;

async fn handle_request(req: Request<Body>, sessions: Sessions) -> Result<Response<Body>, Infallible> {
    let response = match (req.method(), req.uri().path()) {
        (&Method::GET, "/health") => {
            let json = serde_json::json!({"status": "Game service is running"});
            Response::builder()
                .status(StatusCode::OK)
                .header("content-type", "application/json")
                .header("access-control-allow-origin", "*")
                .body(Body::from(json.to_string()))
                .unwrap()
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
                    println!("Created game session {} for user {}", session_id, payload.user_id);

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

                                        println!("Updated game session {}", session_id);
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
                .body(Body::from("Not found"))
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

    println!("Game service starting on port {}", port);

    if let Err(e) = server.await {
        eprintln!("Server error: {}", e);
    }
}
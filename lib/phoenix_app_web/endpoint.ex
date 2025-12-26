defmodule PhoenixAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_app

  @session_options [
    store: :cookie,
    key: "_phoenix_app_key",
    signing_salt: "phoenix_app_session",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, 
    websocket: [
      connect_info: [session: @session_options],
      timeout: 45_000,  # 45 second timeout (default is 60s)
      compress: true    # Enable compression for faster data transfer
    ],
    longpoll: [
      connect_info: [session: @session_options],
      timeout: 45_000
    ]
  socket "/socket", PhoenixAppWeb.UserSocket,
    websocket: [
      timeout: 45_000,
      compress: true
    ],
    longpoll: false

  # Serve user uploads from mounted PVC (/app/uploads) or local uploads folder
  plug Plug.Static,
    at: "/uploads",
    from: if(File.exists?("/app/uploads"), do: "/app/uploads", else: "uploads"),
    gzip: false,
    cache_control_for_etags: "public, max-age=31536000"

  # Serve additional static asset folders for 3D world (models + terrain heightmaps)
  plug Plug.Static,
    at: "/",
    from: :phoenix_app,
    gzip: true,
    brotli: true,
    cache_control_for_etags: "public, max-age=31536000",
    only: ~w(assets css js fonts images favicon.ico robots.txt terrain heightmaps models tri.gif)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :phoenix_app
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug PhoenixAppWeb.Router
end
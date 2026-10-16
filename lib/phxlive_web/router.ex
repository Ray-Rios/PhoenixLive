defmodule PhxliveWeb.Router do
  use PhxliveWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug PhxliveWeb.Plugs.IpBlockerPlug
    plug PhxliveWeb.Plugs.SuspiciousRequestPlug
    plug PhxliveWeb.Plugs.HoneypotPlug
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PhxliveWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug PhxliveWeb.Plugs.RateLimitPlug, endpoint: "api_general"
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug Guardian.Plug.Pipeline, module: Phxlive.Auth.Guardian,
                                  error_handler: PhxliveWeb.AuthErrorHandler
    plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
    plug Guardian.Plug.LoadResource, allow_blank: true
    plug PhxliveWeb.Plugs.RateLimitPlug, endpoint: "auth_login"
  end

  # Gameplay traffic (character list/create, server list, holo-sim CRUD,
  # server heartbeats). Needs the SAME Guardian behaviour as :api_auth -
  # allow_blank: true, because a dedicated-server call authenticates with the
  # server API key instead of a player bearer token and must not be rejected
  # by Guardian before the controller ever sees it (that rules out
  # :api_authenticated, whose EnsureAuthenticated plug would 401 those calls).
  # What it must NOT share is :api_auth's rate limit bucket: that bucket is
  # "auth_login" at 5 attempts / 5 minutes, sized for login POSTs, and every
  # character refresh, server list poll and heartbeat from a single player or
  # server was quietly spending it - a session that logs in and then opens the
  # character screen a couple of times exhausts it before doing anything else.
  pipeline :games_api do
    plug :accepts, ["json"]
    plug Guardian.Plug.Pipeline, module: Phxlive.Auth.Guardian,
                                  error_handler: PhxliveWeb.AuthErrorHandler
    plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
    plug Guardian.Plug.LoadResource, allow_blank: true
    plug PhxliveWeb.Plugs.RateLimitPlug, endpoint: "api_general"
  end

  # games_api without :accepts. Release blobs are binary downloads, and a
  # client that says "Accept: application/octet-stream" (the launcher did, in
  # its first build) is refused by accepts(["json"]) with a 406 before the
  # controller runs - which also stopped that launcher updating itself.
  pipeline :games_blob do
    plug Guardian.Plug.Pipeline, module: Phxlive.Auth.Guardian,
                                  error_handler: PhxliveWeb.AuthErrorHandler
    plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
    plug Guardian.Plug.LoadResource, allow_blank: true
    plug PhxliveWeb.Plugs.RateLimitPlug, endpoint: "api_general"
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug Guardian.Plug.Pipeline, module: Phxlive.Auth.Guardian,
                                  error_handler: PhxliveWeb.AuthErrorHandler
    plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
    plug Guardian.Plug.EnsureAuthenticated
    plug Guardian.Plug.LoadResource
  end
  
  pipeline :quiet_health do
    plug PhxliveWeb.Plugs.QuietHealthCheck
  end

  # Drive file bodies (PHXLIVE.md §7). Not :browser - that pipeline's
  # `accepts ["html"]` would refuse some <img>/<video> requests - and no CSRF,
  # since these are GET-only reads authorised per file by DriveController.
  pipeline :drive_files do
    plug PhxliveWeb.Plugs.IpBlockerPlug
    plug :fetch_session
    plug PhxliveWeb.Auth
  end

  scope "/", PhxliveWeb do
    pipe_through :drive_files

    get "/files/:id", DriveController, :show
    get "/s/:token", DriveController, :shared
  end

  # --------------------
  # Plugins (PHXLIVE.md §9): one gate pipeline per installed plugin. Their
  # routes are expanded below: API before the core /api/games/:game_slug
  # scopes, pages after the main live_session.
  # --------------------
  import PhxliveWeb.PluginRouter
  plugin_pipelines()

  # --------------------
  # Public LiveViews
  # --------------------
  scope "/", PhxliveWeb do
    pipe_through :browser

    # Single live_session for all LiveViews - enables seamless navigation
    # Admin routes use :require_admin_user on_mount for access control
    live_session :app,
    on_mount: {PhxliveWeb.UserAuth, :default},
    session: %{},
    layout: {PhxliveWeb.Layouts, :app} do

    # Homepage is always public
    live "/", HomeLive, :index

    # Public auth routes
    live "/login", AuthLive, :login
    live "/register", AuthLive, :register
    live "/forgot-password", ForgotPasswordLive, :index
    live "/reset-password", ResetPasswordLive, :index
    live "/auth/verify", AuthLive, :verify_code
    live "/auth/verify-email", AuthLive, :verify_email
    live "/auth/resend-verification", AuthLive, :resend_verification

    # Public blog/shop/chat/etc.
    live "/blog", BlogLive, :index
    live "/blog/:slug", BlogLive, :show
    
    live "/pages/:slug", PageLive, :show
    live "/shop", ShopLive, :index
    live "/shop/category/:slug", ShopLive, :category
    live "/shop/product/:id", ShopLive, :product
    live "/cart", CartLive, :index
    live "/checkout", CheckoutLive, :index
    live "/forum", ForumLive, :index
    live "/forum/:channel_id", ForumLive, :channel
    live "/games", GamesLive, :index

    # Profile routes (with auth check in mount)
    live "/profile", ProfileLive, :index
    live "/profile/security", ProfileLive, :security
    live "/profile/orders", ProfileLive, :orders
    live "/profile/uploads", ProfileUploadsLive, :index
    live "/avatar", AvatarLive, :index

    # Admin routes - access controlled in each LiveView's mount
    live "/admin", AdminLive.Dashboard, :index
    live "/admin/blog-management", AdminLive.BlogManagement, :index
    live "/admin/blog-management/:id", AdminLive.BlogManagement, :edit
    live "/admin/pages", AdminLive.Pages, :index
    live "/admin/pages/:id", AdminLive.Pages, :edit
    live "/admin/products", AdminLive.Products, :index
    live "/admin/orders", AdminLive.Orders, :index
    live "/admin/projects", AdminLive.Projects, :index
    live "/admin/scheduler", AdminLive.Scheduler, :index
    live "/admin/subscriptions", AdminLive.Subscriptions, :index
    live "/admin/uploads", AdminLive.Uploads, :index
    live "/admin/user-management", AdminLive.UserManagementLive, :index
    live "/admin/sql", AdminLive.SQL, :index
    live "/admin/security", AdminLive.Security, :index
    live "/admin/emails", AdminLive.Emails, :index
    live "/admin/api-toolbox", AdminLive.ApiToolbox, :index
    live "/admin/custom-emojis", AdminLive.CustomEmojis, :index
    live "/admin/plugins", AdminLive.Plugins, :index

  end
  end

  # Plugin pages: /games/<plugin slug>/..., one live_session per plugin.
  plugin_browser_routes()

  # Plugin admin pages: /admin/<plugin slug>/..., admins only.
  plugin_admin_routes()

  # --------------------
  # Auth Controller Actions (non-Live)
  # --------------------
  scope "/", PhxliveWeb do
    pipe_through :browser

    get "/auth/login_success", AuthController, :login_success
    get "/games/:game_slug/launcher", LauncherDownloadController, :show
    get "/auth/logout", AuthController, :logout
    post "/auth/logout", AuthController, :logout
    post "/auth/2fa/verify", AuthController, :verify_2fa
    post "/auth/2fa/setup", AuthController, :setup_2fa
  end

  # --------------------
  # GraphQL API Authentication
  # --------------------
  scope "/api/auth", PhxliveWeb do
    pipe_through :api

    # Public auth endpoints
    post "/register", Api.ApiAuthController, :register
    post "/login", Api.ApiAuthController, :login
    post "/authenticate", Api.ApiAuthController, :authenticate
    post "/verify", Api.ApiAuthController, :verify_token
    post "/logout", Api.ApiAuthController, :logout
    
    # Email verification endpoints
    post "/verify-email", Api.ApiAuthController, :verify_email
    post "/verify-code", Api.ApiAuthController, :verify_code  # New 6-digit code verification
    post "/resend-verification", Api.ApiAuthController, :resend_verification
    post "/dev-verify", Api.ApiAuthController, :dev_verify  # Development only
    
    # Admin-only endpoints
    get "/users", Api.ApiAuthController, :list_users

    # Project calendar for Taskbar calendar app
    get "/projects/calendar", Api.ProjectController, :calendar
  end

  # --------------------
  # Auth endpoints that read the Authorization header.
  #
  # These MUST NOT sit in the `:api` pipeline above. That pipeline runs no
  # Guardian plugs, so `Guardian.Plug.current_token/1` is always nil there and
  # `verify_bearer` would 401 unconditionally regardless of the token sent.
  # `:api_auth` installs VerifyHeader + LoadResource, which is what these need.
  # --------------------
  scope "/api/auth", PhxliveWeb do
    pipe_through :api_auth

    post "/verify-bearer", Api.ApiAuthController, :verify_bearer
  end

  # --------------------
  # Scheduler Webhook (Public with secret)
  # --------------------
  scope "/api/webhooks", PhxliveWeb do
    pipe_through :api
    
    post "/scheduler/:secret", Api.SchedulerController, :trigger_webhook
  end

  # Plugin APIs: /api/games/<game slug>/... MUST stay above the core
  # "/api/games/:game_slug" scopes, or the dynamic segment captures them.
  plugin_api_routes()

  # --------------------
  # Games Platform API (shared by every game; game-specific APIs are plugins')
  # Auth enforced per-request by GamesApiKeyOrAuth (player JWT or server API key)
  # --------------------
  scope "/api/games", PhxliveWeb do
    pipe_through :games_blob
    get "/:game_slug/releases/blobs/:sha", Api.ReleasesController, :blob
  end

  scope "/api/games", PhxliveWeb do
    pipe_through :games_api

    # Shard registry. `servers` is readable by any authenticated player;
    # `heartbeat` and `offline` are refused unless the caller presented the
    # server API key (enforced in the controller, not here).
    get "/:game_slug/servers", Api.GamesController, :list_servers
    post "/:game_slug/servers/heartbeat", Api.GamesController, :heartbeat_server
    post "/:game_slug/servers/offline", Api.GamesController, :deregister_server

    # Client releases for the launcher. /missing and /:build_id/live are above
    # the bare /blobs/:sha route only for readability - none of them collide.
    get "/:game_slug/releases/latest", Api.ReleasesController, :latest
    post "/:game_slug/releases/missing", Api.ReleasesController, :missing
    post "/:game_slug/releases/:build_id/live", Api.ReleasesController, :set_live
    post "/:game_slug/releases", Api.ReleasesController, :publish

    get "/:game_slug/characters", Api.GamesController, :list_characters
    post "/:game_slug/characters", Api.GamesController, :create_character

    # Single-session claim. Server API key only, enforced in the controller.
    # Above the bare /:id routes for the same reason /access/ and /members/ are
    # above theirs - Phoenix would otherwise be free to read "claim" as an :id.
    post "/:game_slug/characters/:id/claim", Api.GamesController, :claim_character
    post "/:game_slug/characters/:id/release", Api.GamesController, :release_character
    put "/:game_slug/characters/:id/instance_location", Api.GamesController, :set_instance_location
    # The same, under its pre-2026-10-16 name, for clients and servers built
    # before the rename. Remove once they've all been rebuilt.
    put "/:game_slug/characters/:id/holo_location", Api.GamesController, :set_instance_location

    get "/:game_slug/characters/:id", Api.GamesController, :get_character
    put "/:game_slug/characters/:id", Api.GamesController, :update_character
    delete "/:game_slug/characters/:id", Api.GamesController, :delete_character
  end

  # --------------------
  # Scheduler API (Authenticated)
  # --------------------
  scope "/api/scheduler", PhxliveWeb do
    pipe_through :api_authenticated
    
    get "/events", Api.SchedulerController, :list_events
    post "/events", Api.SchedulerController, :create_event
    get "/events/:id", Api.SchedulerController, :get_event
    put "/events/:id", Api.SchedulerController, :update_event
    delete "/events/:id", Api.SchedulerController, :delete_event
    post "/events/:id/run", Api.SchedulerController, :run_event
    post "/events/:id/pause", Api.SchedulerController, :pause_event
    post "/events/:id/resume", Api.SchedulerController, :resume_event
    
    get "/project-events", Api.SchedulerController, :list_project_events
  end

  



  # --------------------
  # Admin API (authenticated + admin-only via controller plug)
  # --------------------
  scope "/api/admin", PhxliveWeb do
    pipe_through :api_authenticated

    get "/users", Api.AdminController, :list_users
    delete "/users/:id", Api.AdminController, :delete_user
    post "/users/:id/enable", Api.AdminController, :enable_user
    post "/users/:id/disable", Api.AdminController, :disable_user
    post "/users/:id/role", Api.AdminController, :update_role
  end

  # --------------------
  # Health Check (for Kubernetes)
  # --------------------
  scope "/", PhxliveWeb do
    pipe_through :quiet_health
    
    get "/health", HealthController, :check
    get "/uploads/signed", UploadController, :signed_download
  end

  # --------------------
  # API (Rust API Migration)
  # --------------------
  scope "/api", PhxliveWeb do
    pipe_through :api

    get "/status", Api.ApiController, :status
    post "/sessions", Api.ApiController, :create_session
  end



  # --------------------
  # GraphQL API
  # --------------------
  scope "/api" do
    pipe_through [:api, PhxliveWeb.Plugs.RateLimitPlug]

    forward "/graphql", Absinthe.Plug,
      schema: PhxliveWeb.Schema

    if Mix.env() == :dev do
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: PhxliveWeb.Schema,
        interface: :simple
    end
  end
end

defmodule PhoenixAppWeb.Router do
  use PhoenixAppWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug PhoenixAppWeb.Plugs.IpBlockerPlug
    plug PhoenixAppWeb.Plugs.SuspiciousRequestPlug
    plug PhoenixAppWeb.Plugs.HoneypotPlug
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PhoenixAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug PhoenixAppWeb.Plugs.RateLimitPlug, endpoint: "api_general"
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug Guardian.Plug.Pipeline, module: PhoenixApp.Auth.Guardian,
                                  error_handler: PhoenixAppWeb.AuthErrorHandler
    plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
    plug Guardian.Plug.LoadResource, allow_blank: true
    plug PhoenixAppWeb.Plugs.RateLimitPlug, endpoint: "auth_login"
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
    plug Guardian.Plug.Pipeline, module: PhoenixApp.Auth.Guardian,
                                  error_handler: PhoenixAppWeb.AuthErrorHandler
    plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
    plug Guardian.Plug.LoadResource, allow_blank: true
    plug PhoenixAppWeb.Plugs.RateLimitPlug, endpoint: "api_general"
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug Guardian.Plug.Pipeline, module: PhoenixApp.Auth.Guardian,
                                  error_handler: PhoenixAppWeb.AuthErrorHandler
    plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
    plug Guardian.Plug.EnsureAuthenticated
    plug Guardian.Plug.LoadResource
  end
  
  pipeline :quiet_health do
    plug PhoenixAppWeb.Plugs.QuietHealthCheck
  end

  # --------------------
  # Public LiveViews
  # --------------------
  scope "/", PhoenixAppWeb do
    pipe_through :browser

    # Single live_session for all LiveViews - enables seamless navigation
    # Admin routes use :require_admin_user on_mount for access control
    live_session :app,
    on_mount: {PhoenixAppWeb.UserAuth, :default},
    session: %{},
    layout: {PhoenixAppWeb.Layouts, :app} do

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
    live "/admin/raysspacesim", AdminLive.RaysSpaceSim, :index

  end
  end

  # --------------------
  # Auth Controller Actions (non-Live)
  # --------------------
  scope "/", PhoenixAppWeb do
    pipe_through :browser

    get "/auth/login_success", AuthController, :login_success
    get "/auth/logout", AuthController, :logout
    post "/auth/logout", AuthController, :logout
    post "/auth/2fa/verify", AuthController, :verify_2fa
    post "/auth/2fa/setup", AuthController, :setup_2fa
  end

  # --------------------
  # GraphQL API Authentication
  # --------------------
  scope "/api/auth", PhoenixAppWeb do
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
  scope "/api/auth", PhoenixAppWeb do
    pipe_through :api_auth

    post "/verify-bearer", Api.ApiAuthController, :verify_bearer
  end

  # --------------------
  # Scheduler Webhook (Public with secret)
  # --------------------
  scope "/api/webhooks", PhoenixAppWeb do
    pipe_through :api
    
    post "/scheduler/:secret", Api.SchedulerController, :trigger_webhook
  end

  # --------------------
  # Games Platform API (RaysSpaceSim and future titles)
  # Auth enforced per-request by GamesApiKeyOrAuth (player JWT or server API key)
  # --------------------
  scope "/api/games", PhoenixAppWeb do
    pipe_through :games_api

    # Shard registry. `servers` is readable by any authenticated player;
    # `heartbeat` and `offline` are refused unless the caller presented the
    # server API key (enforced in the controller, not here).
    get "/:game_slug/servers", Api.GamesController, :list_servers
    post "/:game_slug/servers/heartbeat", Api.GamesController, :heartbeat_server
    post "/:game_slug/servers/offline", Api.GamesController, :deregister_server

    # Holo-sims. Player CRUD and invites use the player token; the access check
    # and state save are server-API-key only, enforced in the controller.
    #
    # Ordering matters: the /access/ and /members/ routes must come before the
    # bare /:id routes, or Phoenix matches "access" as an :id.
    get "/:game_slug/holosims", Api.HoloSimController, :index
    post "/:game_slug/holosims", Api.HoloSimController, :create

    get "/:game_slug/holosims/:id/access/:target_user_id", Api.HoloSimController, :check_access
    put "/:game_slug/holosims/:id/state", Api.HoloSimController, :save_state

    post "/:game_slug/holosims/:id/members", Api.HoloSimController, :add_member
    delete "/:game_slug/holosims/:id/members/:member_user_id", Api.HoloSimController, :remove_member
    post "/:game_slug/holosims/:id/accept", Api.HoloSimController, :accept
    post "/:game_slug/holosims/:id/launch", Api.HoloSimController, :launch
    get "/:game_slug/holosims/:id/status", Api.HoloSimController, :status

    get "/:game_slug/holosims/:id", Api.HoloSimController, :show
    put "/:game_slug/holosims/:id", Api.HoloSimController, :update
    delete "/:game_slug/holosims/:id", Api.HoloSimController, :delete

    get "/:game_slug/characters", Api.GamesController, :list_characters
    post "/:game_slug/characters", Api.GamesController, :create_character
    get "/:game_slug/characters/:id", Api.GamesController, :get_character
    put "/:game_slug/characters/:id", Api.GamesController, :update_character
    delete "/:game_slug/characters/:id", Api.GamesController, :delete_character
  end

  # --------------------
  # Scheduler API (Authenticated)
  # --------------------
  scope "/api/scheduler", PhoenixAppWeb do
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
  scope "/api/admin", PhoenixAppWeb do
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
  scope "/", PhoenixAppWeb do
    pipe_through :quiet_health
    
    get "/health", HealthController, :check
    get "/uploads/signed", UploadController, :signed_download
  end

  # --------------------
  # API (Rust API Migration)
  # --------------------
  scope "/api", PhoenixAppWeb do
    pipe_through :api

    get "/status", Api.ApiController, :status
    post "/sessions", Api.ApiController, :create_session
  end



  # --------------------
  # GraphQL API
  # --------------------
  scope "/api" do
    pipe_through [:api, PhoenixAppWeb.Plugs.RateLimitPlug]

    forward "/graphql", Absinthe.Plug,
      schema: PhoenixAppWeb.Schema

    if Mix.env() == :dev do
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: PhoenixAppWeb.Schema,
        interface: :simple
    end
  end
end

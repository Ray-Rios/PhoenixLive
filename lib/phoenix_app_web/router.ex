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
    live "/world", WorldLive, :index

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
    post "/verify-bearer", Api.ApiAuthController, :verify_bearer
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
  # Scheduler Webhook (Public with secret)
  # --------------------
  scope "/api/webhooks", PhoenixAppWeb do
    pipe_through :api
    
    post "/scheduler/:secret", Api.SchedulerController, :trigger_webhook
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

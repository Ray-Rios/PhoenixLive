defmodule PhoenixAppWeb.Router do
  use PhoenixAppWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {PhoenixAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :game_auth do
    plug PhoenixAppWeb.Plugs.GameAuthPlug
  end

  # --------------------
  # Public LiveViews
  # --------------------
  scope "/", PhoenixAppWeb do
  pipe_through :browser

  live_session :browser,
    on_mount: {PhoenixAppWeb.UserAuth, :default},
    session: %{} do

    # Homepage is always public
    live "/", HomeLive, :index

    # Public auth routes
    live "/login", AuthLive, :login
    live "/register", AuthLive, :register

    # Public blog/shop/chat/etc.
    live "/blog", BlogLive, :index
    live "/blog/:slug", BlogLive, :show
    live "/shop", ShopLive, :index
    live "/shop/category/:slug", ShopLive, :category
    live "/shop/product/:id", ShopLive, :product
    live "/cart", CartLive, :index
    live "/checkout", CheckoutLive, :index
    live "/chat", ChatLive, :index
    live "/chat/:channel_id", ChatLive, :channel
    live "/quest", QuestLive, :index
    live "/unreal", UnrealLive, :index
    live "/desktop", DesktopLive, :index
    live "/terminal", TerminalLive, :index
    live "/galaxy-test", GalaxyTestLive, :index
    live "/galaxy", SimpleGalaxyLive, :index
    live "/galaxy-demo", DemoGalaxyLive, :index


    # Pages
    live "/pages", PageLive.Index, :index
    live "/pages/new", PageLive.Index, :new
    live "/pages/:id/edit", PageLive.Index, :edit
    live "/pages/:id", PageLive.Show, :show
    live "/pages/:id/show/edit", PageLive.Show, :edit
  end
  end

  # --------------------
  # Authenticated LiveViews
  # --------------------
  scope "/", PhoenixAppWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: {PhoenixAppWeb.UserAuth, :require_authenticated_user} do

      live "/dashboard", DashboardLive, :index
      live "/profile", ProfileLive, :index
      live "/profile/security", ProfileLive, :security
      live "/profile/orders", ProfileLive, :orders
      live "/avatar", AvatarLive, :index
      live "/files", FilesLive, :index
      live "/files/upload", FilesLive, :upload
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
  # Admin LiveViews
  # --------------------
  scope "/admin", PhoenixAppWeb do
    pipe_through :browser

    live_session :admin,
      on_mount: {PhoenixAppWeb.UserAuth, :require_admin_user} do

      live "/", AdminDashboardLive, :index
      live "/users", AdminUserLive, :index
      live "/users/:id", AdminUserLive, :show
      live "/analytics", AdminAnalyticsLive, :index
      live "/settings", AdminSettingsLive, :index
      live "/user-management", AdminLive.UserManagementLive, :index
      live "/services", AdminLive.ServicesLive, :index
    end

    # Impact/Level Designer (Weltmeister)
    get "/editor", PageController, :weltmeister
    get "/levels", PageController, :list_levels
    get "/levels/:name", PageController, :get_level
    post "/levels/:name", PageController, :save_level
    put "/levels/:name", PageController, :save_level
  end

  # --------------------
  # Quest Level Editor
  # --------------------
  scope "/", PhoenixAppWeb do
    pipe_through :browser

    get "/quest/editor", QuestController, :editor
  end

  # --------------------
  # Static Impact.js Game Files
  # --------------------
  scope "/", PhoenixAppWeb do
    pipe_through :browser
    
    # Serve Impact.js game files from priv/static
    get "/impact/*path", PageController, :serve_impact_file
  end

  # --------------------
  # Game API
  # --------------------
  scope "/api/game", PhoenixAppWeb do
    pipe_through :api

    # Game Authentication (public endpoints)
    post "/login", GameAuthController, :login
    post "/register", GameAuthController, :register
    post "/refresh_token", GameAuthController, :refresh_token
    
    # New unified authentication endpoints
    post "/auth", Api.GameAuthController, :authenticate
    post "/verify", Api.GameAuthController, :verify_token
    get "/users", Api.GameAuthController, :list_users

    # Protected game routes
    pipe_through :game_auth

    get "/player/profile", GamePlayerController, :profile
    put "/player/profile", GamePlayerController, :update_profile
    get "/player/avatar", GamePlayerController, :avatar
    put "/player/avatar", GamePlayerController, :update_avatar
    get "/player/stats", GamePlayerController, :stats
    put "/player/stats", GamePlayerController, :update_stats
  end
end

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
    plug :fetch_session
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
    session: %{},
    layout: {PhoenixAppWeb.Layouts, :app} do

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
    live "/babylon-test", BabylonTestLive, :index
    live "/lobby", LobbyLive, :index
    live "/profile", ProfileLive, :index
    live "/inventory", InventoryLive, :index

  end
  end

  # --------------------
  # Authenticated LiveViews
  # --------------------
  scope "/", PhoenixAppWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: {PhoenixAppWeb.UserAuth, :require_authenticated_user},
      layout: {PhoenixAppWeb.Layouts, :app} do

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
      on_mount: {PhoenixAppWeb.UserAuth, :require_admin_user},
      layout: {PhoenixAppWeb.Layouts, :app} do

      live "/", AdminLive.BlogManagement, :index
      live "/user-management", UserManagementLive, :index
    end
  end

  scope "/eqemu", PhoenixAppWeb do
    pipe_through :browser

    live_session :eqemu_authenticated,
      on_mount: {PhoenixAppWeb.UserAuth, :require_authenticated_user},
      layout: {PhoenixAppWeb.Layouts, :app} do
  
      live "/admin", EqemuAdminLive, :index
      live "/player", EqemuPlayerLive, :index
      live "/server", EqemuServerLive, :index
    end
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
    
    # Admin-only endpoints
    get "/users", Api.ApiAuthController, :list_users
  end

  # --------------------
  # Health Check (for Kubernetes)
  # --------------------
  scope "/", PhoenixAppWeb do
    get "/health", HealthController, :check
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
  # EQEmu Server API
  # --------------------
  scope "/api/eqemu", PhoenixAppWeb do
    pipe_through :api

    post "/authenticate", Api.EqemuController, :authenticate
    post "/verify_account", Api.EqemuController, :verify_account
    get "/characters/:user_id", Api.EqemuController, :list_characters
    post "/characters", Api.EqemuController, :create_character
  end

  # --------------------
  # GraphQL API
  # --------------------
  scope "/api" do
    pipe_through :api

    forward "/graphql", Absinthe.Plug,
      schema: PhoenixAppWeb.Schema

    if Mix.env() == :dev do
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: PhoenixAppWeb.Schema,
        interface: :simple
    end
  end
end

  GET   /                                  PhoenixAppWeb.HomeLive :index
  GET   /login                             PhoenixAppWeb.AuthLive :login
  GET   /register                          PhoenixAppWeb.AuthLive :register
  GET   /forgot-password                   PhoenixAppWeb.ForgotPasswordLive :index
  GET   /reset-password                    PhoenixAppWeb.ResetPasswordLive :index
  GET   /auth/verify                       PhoenixAppWeb.AuthLive :verify_code
  GET   /auth/verify-email                 PhoenixAppWeb.AuthLive :verify_email
  GET   /auth/resend-verification          PhoenixAppWeb.AuthLive :resend_verification
  GET   /blog                              PhoenixAppWeb.BlogLive :index
  GET   /blog/:slug                        PhoenixAppWeb.BlogLive :show
  GET   /shop                              PhoenixAppWeb.ShopLive :index
  GET   /shop/category/:slug               PhoenixAppWeb.ShopLive :category
  GET   /shop/product/:id                  PhoenixAppWeb.ShopLive :product
  GET   /cart                              PhoenixAppWeb.CartLive :index
  GET   /checkout                          PhoenixAppWeb.CheckoutLive :index
  GET   /chat                              PhoenixAppWeb.ChatLive :index
  GET   /forum/:channel_id                 PhoenixAppWeb.ForumLive :channel
  GET   /games                             PhoenixAppWeb.GamesLive :index
  GET   /profile                           PhoenixAppWeb.ProfileLive :index
  GET   /profile/security                  PhoenixAppWeb.ProfileLive :security
  GET   /profile/orders                    PhoenixAppWeb.ProfileLive :orders
  GET   /avatar                            PhoenixAppWeb.AvatarLive :index

  # Note: PhoenixAppWeb.PhoenixDesktopLive is not a route - it's a global
  # live_component (taskbar + windows) rendered on every authenticated page
  # from the app layout, not tied to a specific URL.

  GET   /auth/login_success                PhoenixAppWeb.AuthController :login_success
  GET   /auth/logout                       PhoenixAppWeb.AuthController :logout
  POST  /auth/logout                       PhoenixAppWeb.AuthController :logout
  POST  /auth/2fa/verify                   PhoenixAppWeb.AuthController :verify_2fa
  POST  /auth/2fa/setup                    PhoenixAppWeb.AuthController :setup_2fa
  GET   /admin                             PhoenixAppWeb.AdminLive.BlogManagement :index
  GET   /admin/user-management             PhoenixAppWeb.UserManagementLive :index
  POST  /api/auth/register                 PhoenixAppWeb.Api.ApiAuthController :register
  POST  /api/auth/login                    PhoenixAppWeb.Api.ApiAuthController :login
  POST  /api/auth/authenticate             PhoenixAppWeb.Api.ApiAuthController :authenticate
  POST  /api/auth/verify                   PhoenixAppWeb.Api.ApiAuthController :verify_token
  POST  /api/auth/verify-bearer            PhoenixAppWeb.Api.ApiAuthController :verify_bearer
  POST  /api/auth/logout                   PhoenixAppWeb.Api.ApiAuthController :logout
  POST  /api/auth/verify-email             PhoenixAppWeb.Api.ApiAuthController :verify_email
  POST  /api/auth/verify-code              PhoenixAppWeb.Api.ApiAuthController :verify_code
  POST  /api/auth/resend-verification      PhoenixAppWeb.Api.ApiAuthController :resend_verification
  POST  /api/auth/dev-verify               PhoenixAppWeb.Api.ApiAuthController :dev_verify
  GET   /api/auth/users                    PhoenixAppWeb.Api.ApiAuthController :list_users
  GET   /health                            PhoenixAppWeb.HealthController :check
  GET   /api/status                        PhoenixAppWeb.Api.ApiController :status
  POST  /api/sessions                      PhoenixAppWeb.Api.ApiController :create_session

  # Games Platform API (server API key or player bearer token - see README)
  GET   /api/games/:game_slug/characters                    PhoenixAppWeb.Api.GamesController :list_characters
  POST  /api/games/:game_slug/characters                    PhoenixAppWeb.Api.GamesController :create_character
  GET   /api/games/:game_slug/characters/:id                PhoenixAppWeb.Api.GamesController :get_character
  PUT   /api/games/:game_slug/characters/:id                PhoenixAppWeb.Api.GamesController :update_character
  DELETE /api/games/:game_slug/characters/:id                PhoenixAppWeb.Api.GamesController :delete_character

  # Scheduler API (Authenticated)
  GET   /api/scheduler/events              PhoenixAppWeb.Api.SchedulerController :list_events
  POST  /api/scheduler/events              PhoenixAppWeb.Api.SchedulerController :create_event
  GET   /api/scheduler/events/:id          PhoenixAppWeb.Api.SchedulerController :get_event
  PUT   /api/scheduler/events/:id          PhoenixAppWeb.Api.SchedulerController :update_event
  DELETE /api/scheduler/events/:id         PhoenixAppWeb.Api.SchedulerController :delete_event
  POST  /api/scheduler/events/:id/run      PhoenixAppWeb.Api.SchedulerController :run_event
  POST  /api/scheduler/events/:id/pause    PhoenixAppWeb.Api.SchedulerController :pause_event
  POST  /api/scheduler/events/:id/resume   PhoenixAppWeb.Api.SchedulerController :resume_event
  GET   /api/scheduler/project-events      PhoenixAppWeb.Api.SchedulerController :list_project_events
  
  # Scheduler Webhook (Public with secret)
  POST  /api/webhooks/scheduler/:secret    PhoenixAppWeb.Api.SchedulerController :trigger_webhook

  *     /api/graphql                       Absinthe.Plug [schema: PhoenixAppWeb.Schema]
  *     /api/graphiql       
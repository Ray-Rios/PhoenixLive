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
  GET   /desktop                           PhoenixAppWeb.DesktopLive :index
  GET   /profile                           PhoenixAppWeb.ProfileLive :index
  GET   /profile/security                  PhoenixAppWeb.ProfileLive :security
  GET   /profile/orders                    PhoenixAppWeb.ProfileLive :orders
  GET   /avatar                            PhoenixAppWeb.AvatarLive :index
  GET   /files                             PhoenixAppWeb.FilesLive :index

  GET   /auth/login_success                PhoenixAppWeb.AuthController :login_success
  GET   /auth/logout                       PhoenixAppWeb.AuthController :logout
  POST  /auth/logout                       PhoenixAppWeb.AuthController :logout
  POST  /auth/2fa/verify                   PhoenixAppWeb.AuthController :verify_2fa
  POST  /auth/2fa/setup                    PhoenixAppWeb.AuthController :setup_2fa
  GET   /admin                             PhoenixAppWeb.AdminLive.BlogManagement :index
  GET   /admin/user-management             PhoenixAppWeb.UserManagementLive :index
  GET   /eqemu/admin                       PhoenixAppWeb.EqemuAdminLive :index
  GET   /eqemu/player                      PhoenixAppWeb.EqemuPlayerLive :index
  GET   /eqemu/server                      PhoenixAppWeb.EqemuServerLive :index
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
  GET   /api/game/profile                  PhoenixAppWeb.Api.GameController :get_profile
  GET   /api/game/characters               PhoenixAppWeb.Api.GameController :list_characters
  POST  /api/game/characters               PhoenixAppWeb.Api.GameController :create_character
  GET   /api/game/inventory/:character_id  PhoenixAppWeb.Api.GameController :get_inventory
  POST  /api/game/login-game               PhoenixAppWeb.Api.GameController :login_to_game
  GET   /health                            PhoenixAppWeb.HealthController :check
  GET   /api/status                        PhoenixAppWeb.Api.ApiController :status
  POST  /api/sessions                      PhoenixAppWeb.Api.ApiController :create_session
  POST  /api/eqemu/authenticate            PhoenixAppWeb.Api.EqemuController :authenticate
  POST  /api/eqemu/verify_account          PhoenixAppWeb.Api.EqemuController :verify_account
  GET   /api/eqemu/characters/:user_id     PhoenixAppWeb.Api.EqemuController :list_characters
  POST  /api/eqemu/characters              PhoenixAppWeb.Api.EqemuController :create_character

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
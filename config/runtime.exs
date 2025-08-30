# config/runtime.exs
import Config

# -------------------------------------------------
# SECRET_KEY_BASE
# -------------------------------------------------
secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    if config_env() == :dev do
      # Dev default if not set
      "dev_secret_key_base_please_change_me_#{:crypto.strong_rand_bytes(16) |> Base.encode64()}"
    else
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by running `mix phx.gen.secret`
      """
    end

# -------------------------------------------------
# LIVE_VIEW_SIGNING_SALT
# -------------------------------------------------
live_view_salt =
  System.get_env("LIVE_VIEW_SIGNING_SALT") ||
    if config_env() == :dev do
      # Dev default if not set
      "dev_live_view_salt_please_change_#{:crypto.strong_rand_bytes(8) |> Base.encode64()}"
    else
      raise """
      environment variable LIVE_VIEW_SIGNING_SALT is missing.
      You can generate one by running `mix phx.gen.secret`
      """
    end

# -------------------------------------------------
# Endpoint config
# -------------------------------------------------
config :phoenix_app, PhoenixAppWeb.Endpoint,
  secret_key_base: secret_key_base,
  live_view: [signing_salt: live_view_salt],
  server: true

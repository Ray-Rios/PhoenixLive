defmodule PhoenixApp.PresenceTracker do
  use Phoenix.Presence,
    otp_app: :phoenix_app,
    pubsub_server: PhoenixApp.PubSub

  def track_user(user_id, socket) do
    track(socket, "users:lobby", user_id, %{
      online_at: inspect(System.system_time(:second)),
      user_id: user_id
    })
  end

  def untrack_user(user_id, socket) do
    untrack(socket, "users:lobby", user_id)
  end

  def list_online_users do
    list("users:lobby")
  end
end
defmodule PhoenixAppWeb.Presence do
  @moduledoc """
  Phoenix Presence implementation for tracking online users in real-time.
  
  Used by:
  - Collaborative editing channels to show who's editing
  - Chat/forum to show who's online
  - Desktop app to show presence indicators
  """
  use Phoenix.Presence,
    otp_app: :phoenix_app,
    pubsub_server: PhoenixApp.PubSub
end

defmodule PhoenixAppWeb.GalaxyTestLive do
  use PhoenixAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, message: "Galaxy Test Working!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8 bg-black text-white min-h-screen">
      <h1 class="text-4xl mb-4">🌌 <%= @message %></h1>
      <p class="text-blue-200">If you can see this, the route is working!</p>
    </div>
    """
  end
end
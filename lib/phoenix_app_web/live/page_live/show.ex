defmodule PhoenixAppWeb.PageLive.Show do
  use PhoenixAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Page")}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    {:noreply, assign(socket, page_title: "Page #{id}")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900">
      <div class="container mx-auto px-4 py-8">
        <div class="max-w-4xl mx-auto">
          <h1 class="text-4xl font-bold text-white text-center mb-8">Page Details</h1>
          
          <div class="bg-white bg-opacity-10 backdrop-blur-sm rounded-xl p-8 text-center text-white">
            <p class="text-lg">Page functionality coming soon!</p>
            <.link navigate={~p"/pages"} class="inline-block mt-4 bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg transition-colors duration-300">
              Back to Pages
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
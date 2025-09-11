defmodule PhoenixAppWeb.ProfileLive do
  use PhoenixAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       user: %{
         name: "Player One",
         level: 42,
         experience: 15750,
         achievements: ["First Steps", "Explorer", "Collector"],
         stats: %{
           strength: 18,
           dexterity: 14,
           intelligence: 16,
           charisma: 12
         }
       }
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; min-height: 100vh;">
      <h1 style="font-size: 2rem; margin-bottom: 20px;">Player Profile</h1>
      
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
        <div style="background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px;">
          <h2>Character Info</h2>
          <p><strong>Name:</strong> <%= @user.name %></p>
          <p><strong>Level:</strong> <%= @user.level %></p>
          <p><strong>Experience:</strong> <%= @user.experience %> XP</p>
        </div>
        
        <div style="background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px;">
          <h2>Stats</h2>
          <%= for {stat, value} <- @user.stats do %>
            <div style="display: flex; justify-content: space-between; margin: 5px 0;">
              <span><%= String.capitalize(to_string(stat)) %>:</span>
              <span><%= value %></span>
            </div>
          <% end %>
        </div>
        
        <div style="background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; grid-column: span 2;">
          <h2>Achievements</h2>
          <div style="display: flex; gap: 10px; flex-wrap: wrap;">
            <%= for achievement <- @user.achievements do %>
              <span style="background: rgba(255,255,255,0.2); padding: 5px 10px; border-radius: 15px; font-size: 0.9rem;">
                🏆 <%= achievement %>
              </span>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
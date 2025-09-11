defmodule PhoenixAppWeb.InventoryLive do
  use PhoenixAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       inventory: [
         %{id: 1, name: "Magic Sword", type: "weapon", rarity: "legendary", quantity: 1},
         %{id: 2, name: "Health Potion", type: "consumable", rarity: "common", quantity: 15},
         %{id: 3, name: "Dragon Scale", type: "material", rarity: "epic", quantity: 3},
         %{id: 4, name: "Leather Boots", type: "armor", rarity: "uncommon", quantity: 1},
         %{id: 5, name: "Mana Crystal", type: "material", rarity: "rare", quantity: 7}
       ],
       selected_item: nil
     )}
  end

  @impl true
  def handle_event("select_item", %{"item_id" => item_id}, socket) do
    item_id = String.to_integer(item_id)
    selected_item = Enum.find(socket.assigns.inventory, &(&1.id == item_id))
    {:noreply, assign(socket, selected_item: selected_item)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="padding: 20px; background: linear-gradient(135deg, #2d1b69 0%, #11998e 100%); color: white; min-height: 100vh;">
      <h1 style="font-size: 2rem; margin-bottom: 20px;">Inventory</h1>
      
      <div style="display: grid; grid-template-columns: 2fr 1fr; gap: 20px;">
        <div style="background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px;">
          <h2>Items</h2>
          <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 10px; margin-top: 15px;">
            <%= for item <- @inventory do %>
              <div phx-click="select_item" phx-value-item_id={item.id}
                   style={"background: #{rarity_color(item.rarity)}; padding: 15px; border-radius: 8px; cursor: pointer; text-align: center; transition: transform 0.2s; #{if @selected_item && @selected_item.id == item.id, do: "transform: scale(1.05); box-shadow: 0 0 20px rgba(255,255,255,0.3);", else: ""}"}>
                <div style="font-size: 2rem; margin-bottom: 5px;"><%= item_icon(item.type) %></div>
                <div style="font-size: 0.9rem; font-weight: bold;"><%= item.name %></div>
                <%= if item.quantity > 1 do %>
                  <div style="font-size: 0.8rem; opacity: 0.8;">x<%= item.quantity %></div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        
        <div style="background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px;">
          <h2>Item Details</h2>
          <%= if @selected_item do %>
            <div style="margin-top: 15px;">
              <div style="font-size: 1.5rem; margin-bottom: 10px;"><%= item_icon(@selected_item.type) %></div>
              <h3><%= @selected_item.name %></h3>
              <p style="color: #{rarity_color(@selected_item.rarity)}; font-weight: bold; text-transform: capitalize;">
                <%= @selected_item.rarity %>
              </p>
              <p><strong>Type:</strong> <%= String.capitalize(@selected_item.type) %></p>
              <p><strong>Quantity:</strong> <%= @selected_item.quantity %></p>
              
              <div style="margin-top: 20px;">
                <button style="background: #e74c3c; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; margin-right: 10px;">
                  Drop
                </button>
                <%= if @selected_item.type == "consumable" do %>
                  <button style="background: #27ae60; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer;">
                    Use
                  </button>
                <% end %>
              </div>
            </div>
          <% else %>
            <p style="opacity: 0.7; margin-top: 15px;">Select an item to view details</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp rarity_color("common"), do: "rgba(169, 169, 169, 0.3)"
  defp rarity_color("uncommon"), do: "rgba(30, 255, 0, 0.3)"
  defp rarity_color("rare"), do: "rgba(0, 112, 255, 0.3)"
  defp rarity_color("epic"), do: "rgba(163, 53, 238, 0.3)"
  defp rarity_color("legendary"), do: "rgba(255, 128, 0, 0.3)"

  defp item_icon("weapon"), do: "⚔️"
  defp item_icon("armor"), do: "🛡️"
  defp item_icon("consumable"), do: "🧪"
  defp item_icon("material"), do: "💎"
  defp item_icon(_), do: "📦"
end
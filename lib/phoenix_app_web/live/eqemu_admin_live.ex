# lib/phoenix_app_web/live/eqemu_admin_live.ex
defmodule PhoenixAppWeb.EqemuAdminLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.EqemuGame
  alias PhoenixApp.EqemuGame.{Character, Item}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    if user && user.is_admin do
      characters = EqemuGame.list_characters()
      items = EqemuGame.list_items(limit: 100)
      zones = EqemuGame.list_zones()
      
      {:ok, assign(socket,
        page_title: "EQEmu Administration",
        characters: characters,
        items: items,
        zones: zones,
        selected_character: nil,
        view_mode: :characters,
        search_query: "",
        show_create_modal: false,
        create_form: nil,
        edit_form: nil,
        modal_type: "character"
      )}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_params(%{"view" => view}, _uri, socket) do
    {:noreply, assign(socket, view_mode: String.to_atom(view))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("switch_view", %{"view" => view}, socket) do
    {:noreply, push_patch(socket, to: "/eqemu/admin?view=#{view}")}
  end

  def handle_event("search", %{"query" => query}, socket) do
    case socket.assigns.view_mode do
      :characters ->
        characters = EqemuGame.search_characters(query)
        {:noreply, assign(socket, characters: characters, search_query: query)}
      
      :items ->
        items = EqemuGame.search_items(query)
        {:noreply, assign(socket, items: items, search_query: query)}
      
      :zones ->
        zones = EqemuGame.search_zones(query)
        {:noreply, assign(socket, zones: zones, search_query: query)}
      
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("select_character", %{"character_id" => character_id}, socket) do
    character = EqemuGame.get_character_with_details(character_id)
    {:noreply, assign(socket, selected_character: character)}
  end

  # Create/Edit Modal Events
  def handle_event("show_create_modal", %{"type" => type}, socket) do
    form = case type do
      "character" -> Character.changeset(%Character{}, %{})
      "item" -> Item.changeset(%Item{}, %{})
      _ -> nil
    end
    
    {:noreply, assign(socket, 
      show_create_modal: true, 
      create_form: form,
      modal_type: type
    )}
  end

  def handle_event("hide_create_modal", _params, socket) do
    {:noreply, assign(socket, 
      show_create_modal: false, 
      create_form: nil,
      edit_form: nil
    )}
  end

  def handle_event("validate_create", %{"character" => params}, socket) when socket.assigns.modal_type == "character" do
    changeset = 
      %Character{}
      |> Character.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, create_form: changeset)}
  end

  def handle_event("validate_create", %{"item" => params}, socket) when socket.assigns.modal_type == "item" do
    changeset = 
      %Item{}
      |> Item.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, create_form: changeset)}
  end

  def handle_event("create_character", %{"character" => character_params}, socket) do
    user = socket.assigns.current_user
    
    case EqemuGame.create_character(user, character_params) do
      {:ok, character} ->
        characters = EqemuGame.list_characters()
        {:noreply, assign(socket, 
          characters: characters,
          show_create_modal: false,
          create_form: nil
        ) |> put_flash(:info, "Character '#{character.name}' created successfully")}
      
      {:error, changeset} ->
        {:noreply, assign(socket, create_form: changeset)}
    end
  end

  def handle_event("create_item", %{"item" => item_params}, socket) do
    # Generate next item ID
    next_id = case EqemuGame.list_items(limit: 1000) |> Enum.map(&(&1.eqemu_id || 0)) |> Enum.max() do
      nil -> 1000
      max_id -> max_id + 1
    end
    
    item_params = Map.put(item_params, "eqemu_id", next_id)
    
    case EqemuGame.create_item(item_params) do
      {:ok, item} ->
        items = EqemuGame.list_items(limit: 100)
        {:noreply, assign(socket, 
          items: items,
          show_create_modal: false,
          create_form: nil
        ) |> put_flash(:info, "Item '#{item.name}' created successfully")}
      
      {:error, changeset} ->
        {:noreply, assign(socket, create_form: changeset)}
    end
  end

  def handle_event("delete_character", %{"character_id" => character_id}, socket) do
    character = EqemuGame.get_character!(character_id)
    
    case EqemuGame.delete_character(character) do
      {:ok, _} ->
        characters = EqemuGame.list_characters()
        {:noreply, assign(socket, 
          characters: characters,
          selected_character: nil
        ) |> put_flash(:info, "Character deleted successfully")}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete character")}
    end
  end

  def handle_event("delete_item", %{"item_id" => item_id}, socket) do
    item = EqemuGame.get_item!(item_id)
    
    case EqemuGame.delete_item(item) do
      {:ok, _} ->
        items = EqemuGame.list_items(limit: 100)
        {:noreply, assign(socket, items: items) 
         |> put_flash(:info, "Item '#{item.name}' deleted successfully")}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete item")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="starry-background min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-indigo-900">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <!-- Create/Edit Modal -->
      <div :if={@show_create_modal} class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-gray-800 rounded-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-white text-lg font-semibold">
              Create <%= String.capitalize(@modal_type || "Item") %>
            </h3>
            <button phx-click="hide_create_modal" class="text-gray-400 hover:text-white">X</button>
          </div>
          
          <%= if @modal_type == "character" do %>
            <.form for={@create_form} phx-submit="create_character" phx-change="validate_create">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">Character Name</label>
                  <.input field={@create_form[:name]} type="text" class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">Level</label>
                  <.input field={@create_form[:level]} type="number" min="1" max="65" class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">Race</label>
                  <.input field={@create_form[:race]} type="select" options={race_options()} class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">Class</label>
                  <.input field={@create_form[:class]} type="select" options={class_options()} class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">Gender</label>
                  <.input field={@create_form[:gender]} type="select" options={[{"Male", 0}, {"Female", 1}, {"Neuter", 2}]} class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">Zone ID</label>
                  <.input field={@create_form[:zone_id]} type="number" value="1" class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
              </div>
              
              <div class="flex justify-end space-x-3 mt-6">
                <button type="button" phx-click="hide_create_modal" class="px-4 py-2 text-gray-300 hover:text-white">Cancel</button>
                <button type="submit" class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded">Create Character</button>
              </div>
            </.form>
          <% end %>

          <%= if @modal_type == "item" do %>
            <.form for={@create_form} phx-submit="create_item" phx-change="validate_create">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="md:col-span-2">
                  <label class="block text-gray-300 text-sm font-medium mb-2">Item Name</label>
                  <.input field={@create_form[:name]} type="text" class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">Item Type</label>
                  <.input field={@create_form[:itemtype]} type="select" options={item_type_options()} class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">Damage</label>
                  <.input field={@create_form[:damage]} type="number" min="0" class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">AC</label>
                  <.input field={@create_form[:ac]} type="number" min="0" class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">Weight</label>
                  <.input field={@create_form[:weight]} type="number" min="0" step="0.1" class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
                <div>
                  <label class="block text-gray-300 text-sm font-medium mb-2">Required Level</label>
                  <.input field={@create_form[:reqlevel]} type="number" min="1" max="65" class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
                </div>
              </div>
              
              <div class="flex justify-end space-x-3 mt-6">
                <button type="button" phx-click="hide_create_modal" class="px-4 py-2 text-gray-300 hover:text-white">Cancel</button>
                <button type="submit" class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded">Create Item</button>
              </div>
            </.form>
          <% end %>
        </div>
      </div>
      
      <div class="container mx-auto px-4 py-8 relative z-10">
        <!-- Header -->
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold text-white">EQEmu Administration</h1>
          <div class="flex items-center space-x-4">
            <.link navigate="/eqemu/player" class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg">
              Player View
            </.link>
            <.link navigate="/dashboard" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg">
              Dashboard
            </.link>
          </div>
        </div>

        <!-- Navigation Tabs -->
        <div class="bg-gray-800 rounded-lg p-4 mb-6">
          <div class="flex space-x-4">
            <button phx-click="switch_view" phx-value-view="characters"
                    class={["px-4 py-2 rounded-lg transition-colors",
                           if(@view_mode == :characters, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}>
              Characters
            </button>
            <button phx-click="switch_view" phx-value-view="items"
                    class={["px-4 py-2 rounded-lg transition-colors",
                           if(@view_mode == :items, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}>
              Items
            </button>
            <button phx-click="switch_view" phx-value-view="zones"
                    class={["px-4 py-2 rounded-lg transition-colors",
                           if(@view_mode == :zones, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}>
              Zones
            </button>
          </div>
        </div>

        <!-- Search Bar -->
        <div class="bg-gray-800 rounded-lg p-4 mb-6">
          <form phx-change="search" class="flex items-center">
            <div class="relative flex-1">
              <input type="text" name="query" value={@search_query} 
                     placeholder={"Search #{@view_mode}..."}
                     class="w-full bg-gray-700 text-white px-4 py-2 pl-10 rounded-lg focus:ring-2 focus:ring-blue-500" />
              <div class="absolute left-3 top-2.5 text-gray-400">[S]</div>
            </div>
          </form>
        </div>

        <!-- Content Area -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Main Content -->
          <div class="lg:col-span-2">
            <!-- Characters View -->
            <div :if={@view_mode == :characters} class="bg-gray-800 rounded-lg p-6">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-bold text-white">Characters (<%= length(@characters) %>)</h2>
                <button phx-click="show_create_modal" phx-value-type="character" 
                        class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg">
                  + Create Character
                </button>
              </div>
              
              <div class="overflow-x-auto">
                <table class="w-full">
                  <thead class="bg-gray-700">
                    <tr>
                      <th class="px-4 py-3 text-left text-white">Name</th>
                      <th class="px-4 py-3 text-left text-white">Level</th>
                      <th class="px-4 py-3 text-left text-white">Race</th>
                      <th class="px-4 py-3 text-left text-white">Class</th>
                      <th class="px-4 py-3 text-left text-white">Zone</th>
                      <th class="px-4 py-3 text-left text-white">HP/Mana</th>
                      <th class="px-4 py-3 text-left text-white">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for character <- @characters do %>
                      <tr class="border-b border-gray-700 hover:bg-gray-700 transition-colors">
                        <td class="px-4 py-3 text-white font-medium"><%= character.name %></td>
                        <td class="px-4 py-3 text-gray-300"><%= character.level %></td>
                        <td class="px-4 py-3 text-gray-300"><%= EqemuGame.get_race_name(character.race) %></td>
                        <td class="px-4 py-3 text-gray-300"><%= EqemuGame.get_class_name(character.class) %></td>
                        <td class="px-4 py-3 text-gray-300"><%= character.zone_id %></td>
                        <td class="px-4 py-3 text-gray-300"><%= character.hp %>/<%= character.mana %></td>
                        <td class="px-4 py-3">
                          <div class="flex space-x-2">
                            <button phx-click="select_character" phx-value-character_id={character.id}
                                    class="text-blue-400 hover:text-blue-300 text-sm">View</button>
                            <button class="text-yellow-400 hover:text-yellow-300 text-sm">Edit</button>
                            <button phx-click="delete_character" phx-value-character_id={character.id}
                                    class="text-red-400 hover:text-red-300 text-sm"
                                    onclick="return confirm('Delete this character?')">Delete</button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>

            <!-- Items View -->
            <div :if={@view_mode == :items} class="bg-gray-800 rounded-lg p-6">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-bold text-white">Items (<%= length(@items) %>)</h2>
                <button phx-click="show_create_modal" phx-value-type="item"
                        class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg">
                  + Create Item
                </button>
              </div>
              
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <%= for item <- @items do %>
                  <div class="bg-gray-700 rounded-lg p-4 hover:bg-gray-600 transition-colors">
                    <div class="flex items-center space-x-3 mb-2">
                      <div class="text-sm font-mono"><%= get_item_icon(item.itemtype || 0) %></div>
                      <div class="flex-1">
                        <h3 class="text-white font-medium truncate"><%= item.name %></h3>
                        <p class="text-gray-400 text-sm">ID: <%= item.eqemu_id %></p>
                      </div>
                    </div>
                    
                    <div class="text-sm text-gray-300 space-y-1">
                      <%= if item.damage && item.damage > 0 do %>
                        <div>Damage: <%= item.damage %></div>
                      <% end %>
                      <%= if item.ac && item.ac > 0 do %>
                        <div>AC: <%= item.ac %></div>
                      <% end %>
                      <%= if item.weight && item.weight > 0 do %>
                        <div>Weight: <%= item.weight %></div>
                      <% end %>
                      <%= if item.reqlevel && item.reqlevel > 0 do %>
                        <div>Req Level: <%= item.reqlevel %></div>
                      <% end %>
                    </div>
                    
                    <div class="mt-3 flex space-x-2">
                      <button class="text-blue-400 hover:text-blue-300 text-sm">View</button>
                      <button class="text-yellow-400 hover:text-yellow-300 text-sm">Edit</button>
                      <button phx-click="delete_item" phx-value-item_id={item.id}
                              class="text-red-400 hover:text-red-300 text-sm"
                              onclick="return confirm('Delete this item?')">Delete</button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Zones View -->
            <div :if={@view_mode == :zones} class="bg-gray-800 rounded-lg p-6">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-bold text-white">Zones</h2>
                <button class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg">
                  + Create Zone
                </button>
              </div>
              
              <div class="text-center text-gray-400 py-8">
                <p>Zone management coming soon...</p>
              </div>
            </div>
          </div>

          <!-- Sidebar -->
          <div class="lg:col-span-1">
            <!-- Character Details -->
            <%= if @selected_character do %>
              <div class="bg-gray-800 rounded-lg p-6 mb-6">
                <h3 class="text-xl font-bold text-white mb-4">Character Details</h3>
                
                <div class="space-y-3">
                  <div class="flex justify-between">
                    <span class="text-gray-400">Name:</span>
                    <span class="text-white font-medium"><%= @selected_character.name %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-400">Level:</span>
                    <span class="text-white"><%= @selected_character.level %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-400">Race:</span>
                    <span class="text-white"><%= EqemuGame.get_race_name(@selected_character.race) %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-400">Class:</span>
                    <span class="text-white"><%= EqemuGame.get_class_name(@selected_character.class) %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-400">HP:</span>
                    <span class="text-green-400"><%= @selected_character.hp %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-400">Mana:</span>
                    <span class="text-blue-400"><%= @selected_character.mana %></span>
                  </div>
                </div>

                <div class="mt-6 space-y-2">
                  <button class="w-full bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg">
                    Edit Character
                  </button>
                  <button class="w-full bg-green-600 hover:bg-green-700 text-white py-2 rounded-lg">
                    View Inventory
                  </button>
                </div>
              </div>
            <% end %>

            <!-- Quick Stats -->
            <div class="bg-gray-800 rounded-lg p-6">
              <h3 class="text-xl font-bold text-white mb-4">Quick Stats</h3>
              
              <div class="space-y-3">
                <div class="flex justify-between">
                  <span class="text-gray-400">Total Characters:</span>
                  <span class="text-white font-medium"><%= length(@characters) %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-400">Total Items:</span>
                  <span class="text-white font-medium"><%= length(@items) %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-400">Total Zones:</span>
                  <span class="text-white font-medium"><%= length(@zones) %></span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp get_item_icon(item_type) do
    case item_type do
      0 -> "[SW]"  # 1H Slashing
      1 -> "[2H]"  # 2H Slashing
      2 -> "[PI]"  # 1H Piercing
      3 -> "[BL]"  # 1H Blunt
      4 -> "[2B]"  # 2H Blunt
      5 -> "[AR]"  # Archery
      8 -> "[SH]"  # Shield
      10 -> "[AR]" # Armor
      11 -> "[JW]" # Jewelry
      20 -> "[FD]" # Food
      21 -> "[DR]" # Drink
      22 -> "[LT]" # Light
      23 -> "[CB]" # Combinable
      25 -> "[CT]" # Container
      _ -> "[??]"
    end
  end

  defp race_options do
    [
      {"Human", 1},
      {"Barbarian", 2},
      {"cat", 3},
      {"Wood Elf", 4},
      {"High Elf", 5},
      {"Dark Elf", 6},
      {"Half Elf", 7},
      {"Dwarf", 8},
      {"Troll", 9},
      {"Ogre", 10},
      {"Halfling", 11},
      {"Gnome", 12},
      {"Iksar", 128},
      {"Vah Shir", 130},
      {"Froglok", 330},
      {"Drakkin", 522}
    ]
  end

  defp class_options do
    [
      {"Warrior", 1},
      {"Cleric", 2},
      {"Paladin", 3},
      {"Ranger", 4},
      {"Shadow Knight", 5},
      {"Druid", 6},
      {"Monk", 7},
      {"Bard", 8},
      {"Rogue", 9},
      {"Shaman", 10},
      {"Necromancer", 11},
      {"Wizard", 12},
      {"Magician", 13},
      {"Enchanter", 14},
      {"Beastlord", 15},
      {"Berserker", 16}
    ]
  end

  defp item_type_options do
    [
      {"1H Slashing", 0},
      {"2H Slashing", 1},
      {"1H Piercing", 2},
      {"1H Blunt", 3},
      {"2H Blunt", 4},
      {"Archery", 5},
      {"Shield", 8},
      {"Armor", 10},
      {"Jewelry", 11},
      {"Food", 20},
      {"Drink", 21},
      {"Light", 22},
      {"Combinable", 23},
      {"Container", 25}
    ]
  end
end
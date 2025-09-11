# lib/phoenix_app_web/live/eqemu_player_live.ex
defmodule PhoenixAppWeb.EqemuPlayerLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.EqemuGame
  alias PhoenixApp.EqemuGame.Character

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    if user do
      characters = EqemuGame.list_user_characters(user)
      
      {:ok, assign(socket,
        page_title: "EverQuest",
        characters: characters,
        selected_character: nil,
        game_state: :character_select,
        zones: EqemuGame.list_zones(),
        show_create_character: false,
        character_form: nil,
        view_tab: :stats,
        inventory: [],
        bank_items: []
      )}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_event("select_character", %{"character_id" => character_id}, socket) do
    character = EqemuGame.get_character_with_details(character_id)
    inventory = EqemuGame.get_character_inventory(character_id)
    
    {:noreply, assign(socket, 
      selected_character: character,
      game_state: :in_game,
      inventory: inventory,
      view_tab: :stats
    )}
  end

  def handle_event("show_create_character", _params, socket) do
    form = Character.changeset(%Character{}, %{})
    {:noreply, assign(socket, show_create_character: true, character_form: form)}
  end

  def handle_event("hide_create_character", _params, socket) do
    {:noreply, assign(socket, show_create_character: false, character_form: nil)}
  end

  def handle_event("validate_character", %{"character" => params}, socket) do
    changeset = 
      %Character{}
      |> Character.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, character_form: changeset)}
  end

  def handle_event("create_character", %{"character" => character_params}, socket) do
    user = socket.assigns.current_user
    
    case EqemuGame.create_character(user, character_params) do
      {:ok, character} ->
        characters = EqemuGame.list_user_characters(user)
        {:noreply, assign(socket, 
          characters: characters,
          show_create_character: false,
          character_form: nil
        ) |> put_flash(:info, "Character '#{character.name}' created successfully")}
      
      {:error, changeset} ->
        {:noreply, assign(socket, character_form: changeset)}
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, view_tab: String.to_atom(tab))}
  end

  def handle_event("back_to_character_select", _params, socket) do
    {:noreply, assign(socket, 
      game_state: :character_select,
      selected_character: nil,
      view_tab: :stats
    )}
  end

  def handle_event("enter_world", _params, socket) do
    character = socket.assigns.selected_character
    
    # Initialize character in world
    EqemuGame.enter_world(character)
    
    {:noreply, assign(socket, game_state: :playing)}
  end

  def render(assigns) do
    ~H"""
    <div class="starry-background min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-indigo-900">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <!-- Character Creation Modal -->
      <div :if={@show_create_character} class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-gray-800 rounded-lg p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-white text-lg font-semibold">Create New Character</h3>
            <button phx-click="hide_create_character" class="text-gray-400 hover:text-white">X</button>
          </div>
          
          <.form for={@character_form} phx-submit="create_character" phx-change="validate_character">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="md:col-span-2">
                <label class="block text-gray-300 text-sm font-medium mb-2">Character Name</label>
                <.input field={@character_form[:name]} type="text" 
                        placeholder="Enter character name"
                        class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
              </div>
              
              <div>
                <label class="block text-gray-300 text-sm font-medium mb-2">Race</label>
                <.input field={@character_form[:race]} type="select" 
                        options={race_options()} 
                        class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
              </div>
              
              <div>
                <label class="block text-gray-300 text-sm font-medium mb-2">Class</label>
                <.input field={@character_form[:class]} type="select" 
                        options={class_options()} 
                        class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
              </div>
              
              <div>
                <label class="block text-gray-300 text-sm font-medium mb-2">Gender</label>
                <.input field={@character_form[:gender]} type="select" 
                        options={[{"Male", 0}, {"Female", 1}, {"Neuter", 2}]} 
                        class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
              </div>
              
              <div>
                <label class="block text-gray-300 text-sm font-medium mb-2">Starting Zone</label>
                <.input field={@character_form[:zone_id]} type="select" 
                        options={[{"Qeynos", 1}, {"Freeport", 8}, {"Kelethin", 54}, {"Felwithe", 61}, {"Rivervale", 19}, {"Oggok", 47}, {"Grobb", 52}, {"Neriak", 40}, {"Halas", 29}, {"Paineel", 75}, {"Erudin", 24}, {"Ak'Anon", 55}, {"Cabilis", 106}]} 
                        class="w-full bg-gray-700 text-white px-3 py-2 rounded border border-gray-600" />
              </div>
            </div>
            
            <div class="flex justify-end space-x-3 mt-6">
              <button type="button" phx-click="hide_create_character" 
                      class="px-4 py-2 text-gray-300 hover:text-white">Cancel</button>
              <button type="submit" 
                      class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded">Create Character</button>
            </div>
          </.form>
        </div>
      </div>
      
      <div class="container mx-auto px-4 py-8 relative z-10">
        <!-- Character Select Screen -->
        <%= if @game_state == :character_select do %>
          <div class="max-w-6xl mx-auto">
            <div class="text-center mb-8">
              <h1 class="text-4xl font-bold text-white mb-2">EverQuest</h1>
              <p class="text-gray-300">Select your character to enter Norrath</p>
            </div>

            <!-- Character List -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-8">
              <%= for character <- @characters do %>
                <div class="bg-gray-800 rounded-lg p-6 hover:bg-gray-700 transition-colors cursor-pointer"
                     phx-click="select_character" phx-value-character_id={character.id}>
                  <div class="text-center mb-4">
                    <div class="text-4xl mb-2">[<%= get_character_avatar(character.race, character.gender) %>]</div>
                    <h3 class="text-xl font-bold text-white"><%= character.name %></h3>
                    <p class="text-gray-400">Level <%= character.level %> <%= EqemuGame.get_race_name(character.race) %> <%= EqemuGame.get_class_name(character.class) %></p>
                  </div>
                  
                  <div class="space-y-2 text-sm">
                    <div class="flex justify-between">
                      <span class="text-gray-400">HP:</span>
                      <span class="text-green-400"><%= character.hp %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-400">Mana:</span>
                      <span class="text-blue-400"><%= character.mana %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-400">Zone:</span>
                      <span class="text-white">Zone <%= character.zone_id %></span>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Create New Character -->
              <div phx-click="show_create_character" 
                   class="bg-gray-800 border-2 border-dashed border-gray-600 rounded-lg p-6 hover:border-blue-500 transition-colors cursor-pointer text-center">
                <div class="text-4xl text-gray-400 mb-4">[+]</div>
                <h3 class="text-lg font-medium text-white mb-2">Create New Character</h3>
                <p class="text-gray-400 text-sm">Start your adventure in Norrath</p>
              </div>
            </div>

            <!-- Quick Actions -->
            <div class="text-center">
              <.link navigate="/eqemu/admin" class="bg-gray-600 hover:bg-gray-700 text-white px-6 py-2 rounded-lg mr-4">
                Admin Panel
              </.link>
              <.link navigate="/dashboard" class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg">
                Dashboard
              </.link>
            </div>
          </div>
        <% end %>

        <!-- In-Game Interface -->
        <%= if @game_state == :in_game && @selected_character do %>
          <div class="max-w-7xl mx-auto">
            <!-- Header -->
            <div class="flex justify-between items-center mb-6">
              <div class="flex items-center space-x-4">
                <button phx-click="back_to_character_select" 
                        class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg">
                  &lt;- Back to Character Select
                </button>
                <h1 class="text-2xl font-bold text-white"><%= @selected_character.name %></h1>
                <span class="text-gray-400">Level <%= @selected_character.level %> <%= EqemuGame.get_race_name(@selected_character.race) %> <%= EqemuGame.get_class_name(@selected_character.class) %></span>
              </div>
              <div class="flex items-center space-x-4">
                <.link navigate="/eqemu/admin" class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg">
                  Admin
                </.link>
              </div>
            </div>

            <!-- Tab Navigation -->
            <div class="bg-gray-800 rounded-lg p-4 mb-6">
              <div class="flex space-x-4">
                <button phx-click="switch_tab" phx-value-tab="stats"
                        class={["px-4 py-2 rounded-lg transition-colors",
                               if(@view_tab == :stats, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}>
                  Stats
                </button>
                <button phx-click="switch_tab" phx-value-tab="inventory"
                        class={["px-4 py-2 rounded-lg transition-colors",
                               if(@view_tab == :inventory, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}>
                  Inventory
                </button>
                <button phx-click="switch_tab" phx-value-tab="equipment"
                        class={["px-4 py-2 rounded-lg transition-colors",
                               if(@view_tab == :equipment, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}>
                  Equipment
                </button>
                <button phx-click="switch_tab" phx-value-tab="bank"
                        class={["px-4 py-2 rounded-lg transition-colors",
                               if(@view_tab == :bank, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}>
                  Bank
                </button>
                <button phx-click="switch_tab" phx-value-tab="spells"
                        class={["px-4 py-2 rounded-lg transition-colors",
                               if(@view_tab == :spells, do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")]}>
                  Spells
                </button>
              </div>
            </div>

            <!-- Content Area -->
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <!-- Main Content -->
              <div class="lg:col-span-2">
                <!-- Stats Tab -->
                <div :if={@view_tab == :stats} class="bg-gray-800 rounded-lg p-6">
                  <h2 class="text-xl font-bold text-white mb-6">Character Statistics</h2>
                  
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <!-- Basic Stats -->
                    <div>
                      <h3 class="text-lg font-medium text-white mb-4">Basic Information</h3>
                      <div class="space-y-3">
                        <div class="flex justify-between">
                          <span class="text-gray-400">Level:</span>
                          <span class="text-white font-medium"><%= @selected_character.level %></span>
                        </div>
                        <div class="flex justify-between">
                          <span class="text-gray-400">Experience:</span>
                          <span class="text-purple-400"><%= @selected_character.exp %></span>
                        </div>
                        <div class="flex justify-between">
                          <span class="text-gray-400">AA Points:</span>
                          <span class="text-yellow-400"><%= @selected_character.aa_points %></span>
                        </div>
                        <div class="flex justify-between">
                          <span class="text-gray-400">Zone:</span>
                          <span class="text-white">Zone <%= @selected_character.zone_id %></span>
                        </div>
                        <div class="flex justify-between">
                          <span class="text-gray-400">Position:</span>
                          <span class="text-white"><%= Float.round(@selected_character.x, 1) %>, <%= Float.round(@selected_character.y, 1) %>, <%= Float.round(@selected_character.z, 1) %></span>
                        </div>
                      </div>
                    </div>

                    <!-- Vital Stats -->
                    <div>
                      <h3 class="text-lg font-medium text-white mb-4">Vital Statistics</h3>
                      <div class="space-y-3">
                        <div>
                          <div class="flex justify-between text-sm mb-1">
                            <span class="text-red-400">Hit Points</span>
                            <span class="text-white"><%= @selected_character.hp %></span>
                          </div>
                          <div class="w-full bg-gray-700 rounded-full h-2">
                            <div class="bg-red-500 h-2 rounded-full" style="width: 100%"></div>
                          </div>
                        </div>
                        
                        <div>
                          <div class="flex justify-between text-sm mb-1">
                            <span class="text-blue-400">Mana</span>
                            <span class="text-white"><%= @selected_character.mana %></span>
                          </div>
                          <div class="w-full bg-gray-700 rounded-full h-2">
                            <div class="bg-blue-500 h-2 rounded-full" style="width: 100%"></div>
                          </div>
                        </div>
                        
                        <div>
                          <div class="flex justify-between text-sm mb-1">
                            <span class="text-green-400">Endurance</span>
                            <span class="text-white"><%= @selected_character.endurance %></span>
                          </div>
                          <div class="w-full bg-gray-700 rounded-full h-2">
                            <div class="bg-green-500 h-2 rounded-full" style="width: 100%"></div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Currency -->
                  <div class="mt-6">
                    <h3 class="text-lg font-medium text-white mb-4">Currency</h3>
                    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                      <div class="bg-gray-700 rounded-lg p-3 text-center">
                        <div class="text-yellow-400 text-lg">[P]</div>
                        <div class="text-white font-medium"><%= @selected_character.platinum %></div>
                        <div class="text-gray-400 text-sm">Platinum</div>
                      </div>
                      <div class="bg-gray-700 rounded-lg p-3 text-center">
                        <div class="text-yellow-300 text-lg">[G]</div>
                        <div class="text-white font-medium"><%= @selected_character.gold %></div>
                        <div class="text-gray-400 text-sm">Gold</div>
                      </div>
                      <div class="bg-gray-700 rounded-lg p-3 text-center">
                        <div class="text-gray-300 text-lg">[S]</div>
                        <div class="text-white font-medium"><%= @selected_character.silver %></div>
                        <div class="text-gray-400 text-sm">Silver</div>
                      </div>
                      <div class="bg-gray-700 rounded-lg p-3 text-center">
                        <div class="text-orange-400 text-lg">[C]</div>
                        <div class="text-white font-medium"><%= @selected_character.copper %></div>
                        <div class="text-gray-400 text-sm">Copper</div>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Inventory Tab -->
                <div :if={@view_tab == :inventory} class="bg-gray-800 rounded-lg p-6">
                  <h2 class="text-xl font-bold text-white mb-6">Inventory</h2>
                  
                  <div class="grid grid-cols-8 gap-2">
                    <%= for i <- 1..32 do %>
                      <div class="bg-gray-700 border border-gray-600 rounded aspect-square flex items-center justify-center text-gray-400 hover:bg-gray-600 transition-colors cursor-pointer">
                        <%= if rem(i, 5) == 0 do %>
                          <div class="text-xs">[I]</div>
                        <% else %>
                          <div class="text-xs"><%= i %></div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Equipment Tab -->
                <div :if={@view_tab == :equipment} class="bg-gray-800 rounded-lg p-6">
                  <h2 class="text-xl font-bold text-white mb-6">Equipment</h2>
                  
                  <div class="grid grid-cols-3 gap-6">
                    <!-- Left Side Equipment -->
                    <div class="space-y-4">
                      <div class="equipment-slot">
                        <div class="text-gray-400 text-sm mb-1">Primary</div>
                        <div class="bg-gray-700 border border-gray-600 rounded aspect-square flex items-center justify-center text-gray-400 hover:bg-gray-600 transition-colors cursor-pointer">
                          [W]
                        </div>
                      </div>
                      <div class="equipment-slot">
                        <div class="text-gray-400 text-sm mb-1">Secondary</div>
                        <div class="bg-gray-700 border border-gray-600 rounded aspect-square flex items-center justify-center text-gray-400 hover:bg-gray-600 transition-colors cursor-pointer">
                          [S]
                        </div>
                      </div>
                    </div>

                    <!-- Center (Character) -->
                    <div class="text-center">
                      <div class="text-6xl mb-4">[<%= get_character_avatar(@selected_character.race, @selected_character.gender) %>]</div>
                      <h3 class="text-white font-medium"><%= @selected_character.name %></h3>
                    </div>

                    <!-- Right Side Equipment -->
                    <div class="space-y-4">
                      <div class="equipment-slot">
                        <div class="text-gray-400 text-sm mb-1">Head</div>
                        <div class="bg-gray-700 border border-gray-600 rounded aspect-square flex items-center justify-center text-gray-400 hover:bg-gray-600 transition-colors cursor-pointer">
                          [H]
                        </div>
                      </div>
                      <div class="equipment-slot">
                        <div class="text-gray-400 text-sm mb-1">Chest</div>
                        <div class="bg-gray-700 border border-gray-600 rounded aspect-square flex items-center justify-center text-gray-400 hover:bg-gray-600 transition-colors cursor-pointer">
                          [C]
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Bank Tab -->
                <div :if={@view_tab == :bank} class="bg-gray-800 rounded-lg p-6">
                  <h2 class="text-xl font-bold text-white mb-6">Bank</h2>
                  
                  <div class="mb-4">
                    <h3 class="text-lg font-medium text-white mb-2">Bank Currency</h3>
                    <div class="grid grid-cols-4 gap-4 mb-6">
                      <div class="bg-gray-700 rounded-lg p-3 text-center">
                        <div class="text-yellow-400 text-lg">[P]</div>
                        <div class="text-white font-medium"><%= @selected_character.platinum_bank %></div>
                        <div class="text-gray-400 text-sm">Platinum</div>
                      </div>
                      <div class="bg-gray-700 rounded-lg p-3 text-center">
                        <div class="text-yellow-300 text-lg">[G]</div>
                        <div class="text-white font-medium"><%= @selected_character.gold_bank %></div>
                        <div class="text-gray-400 text-sm">Gold</div>
                      </div>
                      <div class="bg-gray-700 rounded-lg p-3 text-center">
                        <div class="text-gray-300 text-lg">[S]</div>
                        <div class="text-white font-medium"><%= @selected_character.silver_bank %></div>
                        <div class="text-gray-400 text-sm">Silver</div>
                      </div>
                      <div class="bg-gray-700 rounded-lg p-3 text-center">
                        <div class="text-orange-400 text-lg">[C]</div>
                        <div class="text-white font-medium"><%= @selected_character.copper_bank %></div>
                        <div class="text-gray-400 text-sm">Copper</div>
                      </div>
                    </div>
                  </div>

                  <h3 class="text-lg font-medium text-white mb-4">Bank Items</h3>
                  <div class="grid grid-cols-8 gap-2">
                    <%= for i <- 1..24 do %>
                      <div class="bg-gray-700 border border-gray-600 rounded aspect-square flex items-center justify-center text-gray-400 hover:bg-gray-600 transition-colors cursor-pointer">
                        <%= if rem(i, 7) == 0 do %>
                          <div class="text-xs">[B]</div>
                        <% else %>
                          <div class="text-xs"><%= i %></div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Spells Tab -->
                <div :if={@view_tab == :spells} class="bg-gray-800 rounded-lg p-6">
                  <h2 class="text-xl font-bold text-white mb-6">Spells & Abilities</h2>
                  
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                      <h3 class="text-lg font-medium text-white mb-4">Spell Book</h3>
                      <div class="space-y-2">
                        <div class="bg-gray-700 rounded-lg p-3 flex items-center space-x-3">
                          <div class="text-blue-400">[H]</div>
                          <div>
                            <div class="text-white font-medium">Minor Healing</div>
                            <div class="text-gray-400 text-sm">Level 1 Healing Spell</div>
                          </div>
                        </div>
                        <div class="bg-gray-700 rounded-lg p-3 flex items-center space-x-3">
                          <div class="text-red-400">[F]</div>
                          <div>
                            <div class="text-white font-medium">Scorch</div>
                            <div class="text-gray-400 text-sm">Level 4 Damage Spell</div>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div>
                      <h3 class="text-lg font-medium text-white mb-4">Combat Abilities</h3>
                      <div class="space-y-2">
                        <div class="bg-gray-700 rounded-lg p-3 flex items-center space-x-3">
                          <div class="text-yellow-400">[B]</div>
                          <div>
                            <div class="text-white font-medium">Bash</div>
                            <div class="text-gray-400 text-sm">Warrior Combat Skill</div>
                          </div>
                        </div>
                        <div class="bg-gray-700 rounded-lg p-3 flex items-center space-x-3">
                          <div class="text-purple-400">[T]</div>
                          <div>
                            <div class="text-white font-medium">Taunt</div>
                            <div class="text-gray-400 text-sm">Generate Aggro</div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Character Summary Sidebar -->
              <div class="lg:col-span-1">
                <div class="bg-gray-800 rounded-lg p-6 sticky top-4">
                  <div class="text-center mb-6">
                    <div class="text-4xl mb-2">[<%= get_character_avatar(@selected_character.race, @selected_character.gender) %>]</div>
                    <h3 class="text-white font-bold"><%= @selected_character.name %></h3>
                    <p class="text-gray-400">Level <%= @selected_character.level %> <%= EqemuGame.get_class_name(@selected_character.class) %></p>
                  </div>

                  <!-- Quick Actions -->
                  <div class="space-y-2 mb-6">
                    <button class="w-full bg-green-600 hover:bg-green-700 text-white py-2 rounded-lg">
                      Enter World
                    </button>
                    <button class="w-full bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg">
                      Zone to Bind Point
                    </button>
                    <button class="w-full bg-purple-600 hover:bg-purple-700 text-white py-2 rounded-lg">
                      Cast Gate
                    </button>
                  </div>

                  <!-- Quick Stats -->
                  <div class="space-y-3">
                    <div class="flex justify-between">
                      <span class="text-gray-400">Total Money:</span>
                      <span class="text-yellow-400"><%= @selected_character.platinum + @selected_character.gold + @selected_character.silver + @selected_character.copper %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-400">AA Points:</span>
                      <span class="text-yellow-400"><%= @selected_character.aa_points %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-400">Current Zone:</span>
                      <span class="text-white">Zone <%= @selected_character.zone_id %></span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions
  defp get_character_avatar(race, gender) do
    case {race, gender} do
      {1, 0} -> "HM"  # Human Male
      {1, 1} -> "HF"  # Human Female
      {2, 0} -> "BM"  # Barbarian Male
      {2, 1} -> "BF"  # Barbarian Female
      {8, 0} -> "DM"  # Dwarf Male
      {8, 1} -> "DF"  # Dwarf Female
      {4, 0} -> "EM"  # Wood Elf Male
      {4, 1} -> "EF"  # Wood Elf Female
      _ -> "??"
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
end
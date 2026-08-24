defmodule PhoenixAppWeb.AdminLive.RaysSpaceSimCodebase do
  @moduledoc """
  A map of the RaysSpaceSim C++ surface: modules, classes, function signatures
  and the replication surface, read from a generated snapshot.

  ## Why the data is a checked-in file and not something this app computes

  The game lives in `C:\\PhxLive\\RaysSpaceSim`, which is a separate repository
  and is NOT part of the web image. A pod has no headers to parse. So the map
  travels as data: `priv/codemap/codemap.json`, produced by
  `priv/codemap/extract.py` against the game repo and committed alongside it.

  The consequence is the one thing this page must not hide - **it can only be as
  current as that file.** Every screen states the commit the snapshot came from,
  because a code map that is quietly three weeks stale is worse than no map:
  it answers confidently and wrongly.

  ## Why signatures and not a call graph

  1,000-odd functions across 138 classes. A rendered call graph at that size is
  a hairball nobody reads - the standard tools produce one and it gets looked at
  exactly once. What is actually load-bearing here is narrower and is what this
  shows: which module may depend on which (the direction is enforced, see the
  dependency panel), what crosses the wire, and for any given function its
  signature, whether it is an engine override, and which machine it runs on.
  """

  use PhoenixAppWeb, :live_view

  alias PhoenixApp.CodeMap
  alias PhoenixAppWeb.Components.AdminSidebar

  on_mount {PhoenixAppWeb.UserAuth, :require_admin_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load(socket)}
  end

  defp load(socket) do
    case read_map() do
      {:ok, map} ->
        modules = Map.get(map, "modules", [])

        socket
        |> assign(:error, nil)
        |> assign(:map, map)
        |> assign(:modules, modules)
        |> assign(:selected, first_module_name(modules))
        |> assign(:query, "")
        |> assign(:stats, stats(modules))

      {:error, reason} ->
        socket
        |> assign(:error, reason)
        |> assign(:map, %{})
        |> assign(:modules, [])
        |> assign(:selected, nil)
        |> assign(:query, "")
        |> assign(:stats, %{})
    end
  end

  # Resolution lives in PhoenixApp.CodeMap, not here, because two screens read
  # the same snapshot and they must never disagree about which one. The live-ops
  # page reports a commit and a staleness verdict; if this page picked its file
  # by a different rule, that verdict would be about a file nobody is looking at.
  #
  # Read per mount rather than cached. A parse of a megabyte costs tens of
  # milliseconds against one admin reader, and a cache here would mean a
  # redeploy no longer suffices to pick up a regenerated map - exactly the kind
  # of staleness the moduledoc promises not to introduce.
  defp read_map do
    case CodeMap.read() do
      {:ok, json, source} ->
        {:ok, Map.put(json, "__source__", source)}

      {:error, :enoent} ->
        {:error,
         "No snapshot at #{CodeMap.baked_path()}. Regenerate it with " <>
           "./deploy-game.sh --codemap and deploy - see priv/codemap/README.md."}

      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Could not read the snapshot: #{inspect(reason)}"}
    end
  end

  defp first_module_name([%{"name" => n} | _]), do: n
  defp first_module_name(_), do: nil

  defp stats(modules) do
    classes = Enum.flat_map(modules, &Map.get(&1, "classes", []))
    fns = Enum.flat_map(classes, &Map.get(&1, "functions", []))
    props = Enum.flat_map(classes, &Map.get(&1, "properties", []))

    %{
      modules: length(modules),
      classes: length(classes),
      functions: length(fns),
      properties: length(props),
      replicated: Enum.count(props, &Map.get(&1, "replicated")),
      rpcs: Enum.count(fns, &(Map.get(&1, "machine") in ["server-rpc", "client-rpc", "multicast"]))
    }
  end

  @impl true
  def handle_event("select", %{"module" => name}, socket) do
    {:noreply, assign(socket, selected: name, query: "")}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, :query, q)}
  end

  def handle_event("clear", _params, socket), do: {:noreply, assign(socket, :query, "")}

  # ---------------------------------------------------------------------------
  # Selection / filtering
  # ---------------------------------------------------------------------------

  defp searching?(query), do: String.trim(query) != ""

  defp current_module(modules, selected) do
    Enum.find(modules, &(Map.get(&1, "name") == selected)) || List.first(modules)
  end

  # A search crosses module boundaries on purpose. "Where is BeginLocalAttack"
  # is not a question you can answer if you have to guess the module first.
  defp search_hits(modules, query) do
    q = query |> String.trim() |> String.downcase()

    for mod <- modules,
        class <- Map.get(mod, "classes", []),
        hit <- class_hits(class, q),
        do: Map.merge(hit, %{"module" => Map.get(mod, "name")})
  end

  defp class_hits(class, q) do
    name = String.downcase(Map.get(class, "name", ""))
    fns = Map.get(class, "functions", [])
    props = Map.get(class, "properties", [])

    matched_fns = Enum.filter(fns, &String.contains?(String.downcase(Map.get(&1, "sig", "")), q))
    matched_props = Enum.filter(props, &String.contains?(String.downcase(Map.get(&1, "name", "")), q))

    cond do
      String.contains?(name, q) ->
        [%{"class" => class, "functions" => fns, "properties" => props, "whole" => true}]

      matched_fns != [] or matched_props != [] ->
        [%{"class" => class, "functions" => matched_fns, "properties" => matched_props, "whole" => false}]

      true ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Presentation helpers
  # ---------------------------------------------------------------------------

  # The one fact the compiler enforces and a reader cannot see: RSS depends on
  # Cosmos, so Cosmos may never depend on RSS. Everything the plugins need from
  # the game module has to arrive by inversion.
  @project_modules ~w(RSS Cosmos PhxAccount Cockpit_UI RSSAuthTerminal Box3D Box3DPhysics Box3DMass)

  defp project_deps(deps, name) do
    deps
    |> Map.get(name, %{})
    |> Map.get("public", [])
    |> Enum.filter(&(&1 in @project_modules))
  end

  defp machine_badge(nil), do: nil
  defp machine_badge("server-rpc"), do: {"RPC \u2192 server", "bg-amber-900/40 text-amber-300 border-amber-800/60"}
  defp machine_badge("client-rpc"), do: {"RPC \u2192 owner", "bg-sky-900/40 text-sky-300 border-sky-800/60"}
  defp machine_badge("multicast"), do: {"RPC \u2192 all", "bg-fuchsia-900/40 text-fuchsia-300 border-fuchsia-800/60"}
  defp machine_badge("pure"), do: {"pure", "bg-gray-800 text-gray-400 border-gray-700"}
  defp machine_badge(_), do: nil

  defp reliability(nil), do: nil

  defp reliability(uf) do
    # Unreliable FIRST. "Unreliable" does not contain "Reliable" (capital R), so
    # the other order happens to work - but only by the accident of a capital
    # letter, and a spec written "unreliable" would silently read as reliable.
    cond do
      String.contains?(uf, "Unreliable") -> "unreliable"
      String.contains?(uf, "Reliable") -> "reliable"
      true -> nil
    end
  end

  defp short(nil, _), do: nil
  defp short("", _), do: nil

  defp short(text, n) do
    if String.length(text) > n, do: String.slice(text, 0, n) <> "\u2026", else: text
  end

  defp kind_label(%{"uspec" => u, "kind" => k}) do
    cond do
      is_binary(u) and String.contains?(u, "Blueprintable") -> "#{k} \u00b7 blueprintable"
      is_binary(u) and u != "" -> k
      true -> "#{k} \u00b7 plain"
    end
  end

  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <AdminSidebar.admin_layout current_path="/admin/raysspacesim/codebase">
      <div class="mb-8 flex justify-between items-start">
        <div>
          <h1 class="text-3xl font-bold text-white">Codebase</h1>
          <p class="mt-2 text-sm text-gray-400">
            The RaysSpaceSim C++ surface: modules, classes, signatures and what crosses the wire
          </p>
        </div>
        <a
          href="/admin/raysspacesim"
          class="bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
        >
          &larr; Live operations
        </a>
      </div>

      <%= if @error do %>
        <div class="dark-glass shadow rounded-lg p-6 mb-8 border border-amber-900/50">
          <p class="text-amber-300 font-medium">No code map available.</p>
          <p class="mt-3 text-sm text-gray-400"><%= @error %></p>
        </div>
      <% else %>
        <!-- provenance: the single most important thing on the page -->
        <div class="dark-glass shadow rounded-lg px-4 py-3 mb-6 flex items-center justify-between">
          <p class="text-xs text-gray-500">
            Snapshot of
            <span class="text-gray-300 font-mono"><%= Map.get(@map, "generated_from", "unknown") %></span>
            &middot; generated from headers, not hand-written
          </p>
          <p class="text-xs text-gray-600">
            <%= if Map.get(@map, "__source__") == :override do %>
              uploaded snapshot &middot;
            <% end %>
            stale? <span class="font-mono">./deploy-game.sh --codemap</span>, or upload one on
            <a href="/admin/raysspacesim" class="text-gray-500 hover:text-white underline">
              the live-ops page
            </a>
          </p>
        </div>

        <!-- counts -->
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-8">
          <.stat label="modules" value={@stats.modules} />
          <.stat label="classes" value={@stats.classes} />
          <.stat label="functions" value={@stats.functions} />
          <.stat label="properties" value={@stats.properties} />
          <.stat label="replicated" value={@stats.replicated} accent="text-emerald-300" />
          <.stat label="RPCs" value={@stats.rpcs} accent="text-amber-300" />
        </div>

        <!-- dependency direction -->
        <div class="dark-glass shadow rounded-lg overflow-hidden mb-8">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium text-white">Module dependencies</h3>
            <p class="mt-1 text-xs text-gray-500">
              Project modules only; engine modules omitted. Arrows point at what a module is allowed to use.
            </p>

            <div class="mt-5 space-y-2">
              <%= for mod <- @modules do %>
                <% dl = project_deps(Map.get(@map, "deps", %{}), Map.get(mod, "name")) %>
                <div class="flex items-start gap-3 text-sm">
                  <span class="font-mono text-white w-40 shrink-0"><%= Map.get(mod, "name") %></span>
                  <span class="text-gray-600 shrink-0">&rarr;</span>
                  <span class="text-gray-400 font-mono">
                    <%= if dl == [], do: "(engine only)", else: Enum.join(dl, "  ") %>
                  </span>
                </div>
              <% end %>
            </div>

            <div class="mt-5 border-t border-gray-800 pt-4">
              <p class="text-sm text-amber-300 font-medium">
                Cosmos can never depend on RSS, and this is enforced, not a convention.
              </p>
              <p class="mt-2 text-sm text-gray-400">
                <span class="font-mono">RSS</span> lists <span class="font-mono">Cosmos</span>
                as a public dependency, so the reverse is a circular module dependency and
                UnrealBuildTool rejects it outright. It also cannot be unwound:
                <span class="font-mono">ARSSCharacter</span>
                constructs <span class="font-mono">UCosmicFlightComponent</span> and
                <span class="font-mono">UCosmicPlayerRepComponent</span>
                as default subobjects, which is what stops the content-block disconnect.
                Anything a Cosmos component needs from the game module arrives by inversion -
                an interface declared in Cosmos and implemented on the RSS side - or through
                <span class="font-mono">UCosmicPlayerRepComponent</span>, which is why that class exists.
              </p>
            </div>
          </div>
        </div>

        <!-- the wire -->
        <div class="dark-glass shadow rounded-lg overflow-hidden mb-8">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium text-white">Replication surface</h3>
            <p class="mt-1 text-xs text-gray-500">
              Every replicated property in the project. All of it.
            </p>

            <div class="mt-4 overflow-x-auto">
              <table class="min-w-full text-sm">
                <thead>
                  <tr class="text-left text-xs uppercase tracking-wider text-gray-500">
                    <th class="py-2 pr-6">Class</th>
                    <th class="py-2 pr-6">Property</th>
                    <th class="py-2 pr-6">Condition</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-800">
                  <%= for {cls, props} <- Enum.sort(Map.get(@map, "replication_index", %{})) do %>
                    <%= for {prop, cnd} <- Enum.sort(props) do %>
                      <tr>
                        <td class="py-2 pr-6 font-mono text-gray-300"><%= cls %></td>
                        <td class="py-2 pr-6 font-mono text-white"><%= prop %></td>
                        <td class="py-2 pr-6">
                          <span class={
                            "font-mono text-xs px-2 py-0.5 rounded border " <>
                            if(cnd == "COND_None",
                               do: "bg-gray-800 text-gray-400 border-gray-700",
                               else: "bg-emerald-900/40 text-emerald-300 border-emerald-800/60")
                          }>
                            <%= cnd %>
                          </span>
                        </td>
                      </tr>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>

            <p class="mt-4 text-sm text-gray-400">
              A whole multiplayer game on ten properties. That is the design, not an omission:
              positions travel as one packed struct rather than as fields, and everything
              else on the wire is an RPC. <span class="font-mono">COND_SkipOwner</span>
              marks a value whose owner is its author - echoing it back would feed a client
              its own round-tripped state.
            </p>
          </div>
        </div>

        <!-- search -->
        <form phx-change="search" phx-submit="search" class="mb-6">
          <div class="relative">
            <input
              type="text"
              name="q"
              value={@query}
              phx-debounce="200"
              autocomplete="off"
              placeholder="Search every class, function signature and property across all modules&hellip;"
              class="w-full bg-gray-900/70 border border-gray-700 rounded-md px-4 py-2.5 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-gray-500"
            />
            <%= if searching?(@query) do %>
              <button
                type="button"
                phx-click="clear"
                class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300 text-xs px-2 py-1"
              >
                clear
              </button>
            <% end %>
          </div>
        </form>

        <%= if searching?(@query) do %>
          <% hits = search_hits(@modules, @query) %>
          <p class="text-xs text-gray-500 mb-4">
            <%= length(hits) %> matching <%= if length(hits) == 1, do: "class", else: "classes" %>
          </p>
          <%= for hit <- hits do %>
            <.class_card
              cls={hit["class"]}
              functions={hit["functions"]}
              properties={hit["properties"]}
              module={hit["module"]}
              open={true}
            />
          <% end %>
          <%= if hits == [] do %>
            <div class="dark-glass shadow rounded-lg p-6 text-sm text-gray-400">
              Nothing matches &ldquo;<%= @query %>&rdquo;. Search runs over class names,
              full function signatures and property names.
            </div>
          <% end %>
        <% else %>
          <!-- module tabs -->
          <div class="flex flex-wrap gap-2 mb-6">
            <%= for mod <- @modules do %>
              <button
                phx-click="select"
                phx-value-module={Map.get(mod, "name")}
                class={
                  "px-3 py-1.5 rounded-md text-sm font-medium transition-colors border " <>
                  if(Map.get(mod, "name") == @selected,
                     do: "bg-gray-700 text-white border-gray-600",
                     else: "bg-transparent text-gray-400 border-gray-800 hover:text-gray-200 hover:border-gray-700")
                }
              >
                <%= Map.get(mod, "name") %>
                <span class="ml-1.5 text-xs text-gray-500">
                  <%= length(Map.get(mod, "classes", [])) %>
                </span>
              </button>
            <% end %>
          </div>

          <% mod = current_module(@modules, @selected) %>
          <%= if mod do %>
            <p class="text-xs text-gray-500 mb-4">
              <span class="text-gray-400"><%= Map.get(mod, "name") %></span>
              &middot; <%= Map.get(mod, "kind") %>
              &middot; <%= length(Map.get(mod, "classes", [])) %> classes
            </p>

            <%= for class <- Enum.sort_by(Map.get(mod, "classes", []), &Map.get(&1, "name")) do %>
              <.class_card
                cls={class}
                functions={Map.get(class, "functions", [])}
                properties={Map.get(class, "properties", [])}
                module={Map.get(mod, "name")}
                open={false}
              />
            <% end %>
          <% end %>
        <% end %>
      <% end %>
    </AdminSidebar.admin_layout>
    """
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :accent, :string, default: "text-white"

  defp stat(assigns) do
    ~H"""
    <div class="dark-glass shadow rounded-lg px-4 py-3">
      <p class={"text-2xl font-semibold " <> @accent}><%= @value %></p>
      <p class="text-xs uppercase tracking-wider text-gray-500 mt-0.5"><%= @label %></p>
    </div>
    """
  end

  attr :cls, :map, required: true
  attr :functions, :list, required: true
  attr :properties, :list, required: true
  attr :module, :string, required: true
  attr :open, :boolean, default: false

  defp class_card(assigns) do
    ~H"""
    <details class="dark-glass shadow rounded-lg mb-3 group" open={@open}>
      <summary class="px-4 py-3 cursor-pointer list-none flex items-start justify-between gap-4">
        <div class="min-w-0">
          <div class="flex items-center gap-2 flex-wrap">
            <span class="font-mono text-white"><%= Map.get(@cls, "name") %></span>
            <%= if Map.get(@cls, "base", "") != "" do %>
              <span class="text-xs text-gray-500 font-mono">: <%= Map.get(@cls, "base") %></span>
            <% end %>
            <span class="text-[10px] uppercase tracking-wider text-gray-600 border border-gray-800 rounded px-1.5 py-0.5">
              <%= kind_label(@cls) %>
            </span>
            <span class="text-[10px] uppercase tracking-wider text-gray-500 border border-gray-800 rounded px-1.5 py-0.5">
              <%= @module %>
            </span>
            <%= if Map.get(@cls, "replication", %{}) != %{} do %>
              <span class="text-[10px] uppercase tracking-wider text-emerald-300 border border-emerald-800/60 bg-emerald-900/30 rounded px-1.5 py-0.5">
                replicates
              </span>
            <% end %>
          </div>
          <% cdoc = short(Map.get(@cls, "doc"), 190) %>
          <%= if cdoc do %>
            <p class="mt-1.5 text-xs text-gray-500 leading-relaxed"><%= cdoc %></p>
          <% end %>
          <p class="mt-1 text-[11px] text-gray-700 font-mono"><%= Map.get(@cls, "file") %></p>
        </div>
        <div class="text-right shrink-0 text-xs text-gray-500">
          <div><%= length(@functions) %> fn</div>
          <div><%= length(@properties) %> prop</div>
        </div>
      </summary>

      <div class="border-t border-gray-800 px-4 py-4 space-y-6">
        <%= if @functions != [] do %>
          <div>
            <h4 class="text-xs uppercase tracking-wider text-gray-500 mb-3">Functions</h4>
            <div class="space-y-3">
              <%= for fn_ <- @functions do %>
                <div class="border-l-2 border-gray-800 pl-3">
                  <p class="font-mono text-xs text-gray-200 break-all"><%= Map.get(fn_, "sig") %></p>

                  <div class="mt-1.5 flex flex-wrap items-center gap-1.5">
                    <span class="text-[10px] font-mono text-gray-500">
                      returns <span class="text-gray-400"><%= Map.get(fn_, "ret") %></span>
                    </span>

                    <% badge = machine_badge(Map.get(fn_, "machine")) %>
                    <%= if badge do %>
                      <span class={"text-[10px] px-1.5 py-0.5 rounded border " <> elem(badge, 1)}>
                        <%= elem(badge, 0) %>
                      </span>
                    <% end %>

                    <% rel = reliability(Map.get(fn_, "ufunction")) %>
                    <%= if rel do %>
                      <span class="text-[10px] px-1.5 py-0.5 rounded border bg-gray-800 text-gray-400 border-gray-700">
                        <%= rel %>
                      </span>
                    <% end %>

                    <%= if Map.get(fn_, "const") do %>
                      <span class="text-[10px] px-1.5 py-0.5 rounded border bg-gray-800 text-gray-500 border-gray-700">const</span>
                    <% end %>

                    <%= if Map.get(fn_, "static") do %>
                      <span class="text-[10px] px-1.5 py-0.5 rounded border bg-gray-800 text-gray-500 border-gray-700">static</span>
                    <% end %>

                    <%= if Map.get(fn_, "engine_override") do %>
                      <span class="text-[10px] px-1.5 py-0.5 rounded border bg-gray-800 text-gray-600 border-gray-700">
                        engine override
                      </span>
                    <% else %>
                      <% calls = Map.get(fn_, "calls") %>
                      <%= if is_integer(calls) and calls > 0 do %>
                        <span class="text-[10px] text-gray-600"><%= calls %> call sites</span>
                      <% end %>
                    <% end %>
                  </div>

                  <%= if Map.get(fn_, "params", []) != [] do %>
                    <div class="mt-1.5 space-y-0.5">
                      <%= for p <- Map.get(fn_, "params", []) do %>
                        <p class="text-[11px] font-mono text-gray-600">
                          <span class="text-gray-500"><%= Map.get(p, "type") %></span>
                          <span class="text-gray-400"><%= Map.get(p, "name") %></span>
                          <%= if Map.get(p, "default") do %>
                            <span class="text-gray-700">= <%= Map.get(p, "default") %></span>
                          <% end %>
                        </p>
                      <% end %>
                    </div>
                  <% end %>

                  <% fdoc = short(Map.get(fn_, "doc"), 260) %>
                  <%= if fdoc do %>
                    <p class="mt-1.5 text-[11px] text-gray-500 leading-relaxed"><%= fdoc %></p>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if @properties != [] do %>
          <div>
            <h4 class="text-xs uppercase tracking-wider text-gray-500 mb-3">Properties</h4>
            <div class="space-y-1.5">
              <%= for p <- @properties do %>
                <div class="flex items-baseline gap-2 flex-wrap">
                  <span class="font-mono text-[11px] text-gray-500"><%= Map.get(p, "type") %></span>
                  <span class="font-mono text-xs text-gray-200"><%= Map.get(p, "name") %></span>
                  <%= if Map.get(p, "replicated") do %>
                    <span class="text-[10px] px-1.5 py-0.5 rounded border bg-emerald-900/30 text-emerald-300 border-emerald-800/60">
                      <%= Map.get(p, "cond") || Map.get(p, "replicated") %>
                    </span>
                  <% end %>
                  <% pdoc = short(Map.get(p, "doc"), 130) %>
                  <%= if pdoc do %>
                    <span class="text-[11px] text-gray-600"><%= pdoc %></span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </details>
    """
  end
end

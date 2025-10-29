# Global Desktop Environment Architecture

## Problem Statement
Currently, the taskbar and desktop windows are ONLY rendered on `/desktop` page, confined to `desktop_live.ex`. This violates the design goal of a persistent desktop environment that works globally like Windows/macOS.

## Goals
1. **Taskbar visible globally** (like navbar) on all authenticated pages
2. **Windows persist across navigation** (open terminal on /blog, stays open when going to /forum)
3. **Desktop state maintained** (window positions, z-index, content)
4. **Apps launchable from anywhere** (start menu works on any page)

## Proposed Architecture: Desktop LiveView Component

### Core Concept
Create a **persistent LiveView mounted in the layout** that manages all desktop chrome (taskbar + windows), similar to how navbar works but stateful.

```
root.html.heex (layout)
├── Navbar Component (stateless)
├── app.html.heex (@inner_content)
│   ├── Desktop LiveView (persistent, manages taskbar + windows)
│   │   ├── Taskbar Component
│   │   └── Windows (rendered globally)
│   └── Page Content LiveView (blog, forum, profile, etc.)
└── Background (Three.js canvas)
```

### Implementation Plan

#### 1. Create Global Desktop LiveView
**File**: `lib/phoenix_app_web/live/desktop_chrome_live.ex`

```elixir
defmodule PhoenixAppWeb.DesktopChromeLive do
  use PhoenixAppWeb, :live_view
  
  # This LiveView persists across page navigation
  # Uses LiveView 0.20+ sticky assigns
  
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    {:ok, 
     socket
     |> assign(:windows, [])
     |> assign(:next_z_index, 1)
     |> assign(:show_start_menu, false)
     |> assign(:taskbar_visible, true)}
  end
  
  # Handle app launches from any page
  def handle_event("open_app", %{"app" => app}, socket) do
    # Create new window...
  end
  
  # Handle window management
  def handle_event("close_window", %{"id" => id}, socket) do
    # Close window...
  end
  
  def render(assigns) do
    ~H"""
    <div id="desktop-chrome" class="pointer-events-none">
      <!-- Windows layer - positioned above page content -->
      <div class="fixed inset-0 z-40 pointer-events-none">
        <%= for window <- @windows do %>
          <div class="pointer-events-auto">
            <PhoenixAppWeb.Components.Window.desktop_window 
              window={window}
              id={"window-#{window.id}"}
            />
          </div>
        <% end %>
      </div>
      
      <!-- Taskbar - always visible at bottom -->
      <div class="pointer-events-auto">
        <PhoenixAppWeb.Components.Taskbar.taskbar 
          current_user={@current_user}
          open_windows={@windows}
          show_start_menu={@show_start_menu}
        />
      </div>
    </div>
    """
  end
end
```

#### 2. Mount in Layout
**File**: `lib/phoenix_app_web/layouts/app.html.heex`

```heex
<div class="min-h-screen">
  <PhoenixAppWeb.Components.Navigation.navbar current_user={assigns[:current_user]} id_prefix="main-" />
  
  <.flash_group flash={@flash} />
  
  <!-- Desktop Chrome (taskbar + windows) - persists across pages -->
  <%= if assigns[:current_user] do %>
    <.live_render @conn, PhoenixAppWeb.DesktopChromeLive, 
      id: "desktop-chrome",
      session: %{"user_token" => get_session(@conn, :user_token)},
      sticky: true %>
  <% end %>
  
  <!-- Page content -->
  <main class="relative z-10 w-full pb-12">
    <%= @inner_content %>
  </main>
</div>
```

**Key**: `sticky: true` keeps the LiveView alive across navigation!

#### 3. Update Z-Index Strategy
Ensure windows float above page content but below modals:

```css
/* Z-index hierarchy */
- Page content: z-10
- Desktop windows: z-40 (fixed layer)
- Taskbar: z-50
- Modals: z-60
- Tooltips: z-70
```

#### 4. Refactor Desktop Page
**File**: `lib/phoenix_app_web/live/desktop_live.ex`

Desktop page becomes just the "desktop" view (icons, wallpaper):

```elixir
defmodule PhoenixAppWeb.DesktopLive do
  use PhoenixAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      desktop_files: get_desktop_files(),
      selected_files: [],
      context_menu: nil,
      page_title: "Desktop"
    )}
  end
  
  def render(assigns) do
    ~H"""
    <div class="desktop-page h-screen">
      <!-- Desktop icons, right-click menu, etc. -->
      <!-- Taskbar/windows are rendered by DesktopChromeLive -->
    </div>
    """
  end
end
```

### Benefits
✅ Taskbar visible on ALL pages
✅ Windows persist across navigation (sticky LiveView)
✅ Clean event handling (phx-click works naturally)
✅ Proper z-index layering
✅ True OS-like experience
✅ Desktop page becomes just another "view"

### Trade-offs
- Nested LiveViews (chrome + page)
- Need to handle PubSub between chrome and pages if needed
- Initial setup complexity

### Alternative: Phoenix.LiveView.JS Navigation
If sticky LiveViews don't work as expected, use `push_patch` instead of full page navigation to keep LiveView alive.

## Next Steps
1. Create `DesktopChromeLive`
2. Update `app.html.heex` to render it with `sticky: true`
3. Move window management logic from `desktop_live.ex` to `desktop_chrome_live.ex`
4. Update z-index CSS
5. Test navigation between pages with windows open

## Questions to Consider
1. Should taskbar be hideable (like auto-hide)?
2. Should windows minimize to desktop page or taskbar buttons?
3. How to handle window state persistence (localStorage, database)?
4. Should non-desktop pages have reduced chrome (taskbar only)?

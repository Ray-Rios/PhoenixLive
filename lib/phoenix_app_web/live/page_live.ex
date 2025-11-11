defmodule PhoenixAppWeb.PageLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Content

  on_mount {PhoenixAppWeb.UserAuth, :default}

  def mount(%{"slug" => slug}, _session, socket) do
    page = Content.get_page_by_slug(slug)
    
    case page do
      nil ->
        {:ok, socket
         |> put_flash(:error, "Page not found")
         |> push_navigate(to: "/")}
      
      page ->
        if page.is_published or (socket.assigns.current_user && socket.assigns.current_user.is_admin) do
          {:ok, assign(socket,
            page: page,
            page_title: page.title
          )}
        else
          {:ok, socket
           |> put_flash(:error, "Page not found")
           |> push_navigate(to: "/")}
        end
    end
  end

  def render(assigns) do
    # Determine max width based on template type
    max_width = case assigns.page.template_type do
      "full-width" -> "max-w-full"
      "landing" -> "max-w-7xl"
      "sidebar" -> "max-w-6xl"
      _ -> "max-w-[85%]"
    end

    assigns = assign(assigns, :max_width, max_width)

    ~H"""
    <div class="min-h-screen pointer-events-none">
      <div class={"w-full #{@max_width} mx-auto px-4 py-8 relative z-10 pointer-events-auto"}>
        <div class="auth-glass-panel p-8 rounded-xl">
          <!-- Featured Image -->
          <%= if @page.featured_image do %>
            <div class="mb-8 rounded-lg overflow-hidden -mx-8 -mt-8">
              <img src={@page.featured_image} alt={@page.title} class="w-full h-96 object-cover" />
            </div>
          <% end %>

          <article class="prose prose-invert max-w-none">
            <!-- Category Badge -->
            <%= if @page.category do %>
              <div class="mb-4">
                <span class="inline-block px-3 py-1 text-sm rounded-full bg-blue-600 text-white">
                  <%= @page.category %>
                </span>
              </div>
            <% end %>

            <!-- Title -->
            <h1 class="text-4xl font-bold text-white mb-6"><%= @page.title %></h1>
            
            <!-- Excerpt or Meta Description -->
            <%= if @page.excerpt do %>
              <p class="text-xl text-gray-300 mb-8 font-medium"><%= @page.excerpt %></p>
            <% else %>
              <%= if @page.meta_description do %>
                <p class="text-xl text-gray-300 mb-8"><%= @page.meta_description %></p>
              <% end %>
            <% end %>

            <!-- Publish Date -->
            <%= if @page.published_at do %>
              <div class="text-sm text-gray-400 mb-8 flex items-center space-x-4">
                <span>Published: <%= Calendar.strftime(@page.published_at, "%B %d, %Y") %></span>
                <%= if @page.updated_at != @page.inserted_at do %>
                  <span>• Updated: <%= Calendar.strftime(@page.updated_at, "%B %d, %Y") %></span>
                <% end %>
              </div>
            <% end %>

            <hr class="border-gray-700 mb-8" />
            
            <!-- Content -->
            <div class="text-gray-200 leading-relaxed text-lg">
              <%= PhoenixAppWeb.Markdown.render(@page.content) %>
            </div>
          </article>
        </div>
      </div>
    </div>
    """
  end
end

defmodule PhoenixAppWeb.BlogLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Content
  import PhoenixAppWeb.Components.PageContainer

  on_mount {PhoenixAppWeb.UserAuth, :default}

  def mount(_params, _session, socket) do
    posts = Content.list_published_posts()
    recent_posts = Content.get_recent_posts(5)

    {:ok,
     assign(socket,
       posts: posts,
       recent_posts: recent_posts,
       current_slide: 0,
       page_title: "Blog",
       view: :post_list
     )}
  end

  def handle_params(%{"slug" => slug}, _uri, socket) do
    post = Content.get_post_by_slug!(slug)

    {:noreply,
     assign(socket,
       post: post,
       page_title: post.title,
       view: :post_detail
     )}
  end

  def handle_params(_params, _uri, socket) do
    # Back to blog list view
    {:noreply,
     assign(socket,
       page_title: "Blog",
       view: :post_list
     )}
  end

  def handle_event("next_slide", _params, socket) do
    recent_posts = socket.assigns.recent_posts
    current = socket.assigns.current_slide
    next_slide = if current >= length(recent_posts) - 1, do: 0, else: current + 1
    {:noreply, assign(socket, current_slide: next_slide)}
  end

  def handle_event("prev_slide", _params, socket) do
    recent_posts = socket.assigns.recent_posts
    current = socket.assigns.current_slide
    prev_slide = if current == 0, do: length(recent_posts) - 1, else: current - 1
    {:noreply, assign(socket, current_slide: prev_slide)}
  end
  def handle_event("go_to_slide", %{"slide" => slide_str}, socket) do
    slide = String.to_integer(slide_str)
    {:noreply, assign(socket, current_slide: slide)}
  end

  # Helper to get featured image URL - handles both Arc files and plain URLs
  defp get_featured_image_url(post, _version) do
    cond do
      # If featured_image is nil or empty, use default
      is_nil(post.featured_image) or post.featured_image == "" ->
        "/images/default-blog.jpg"
      
      # If featured_image starts with /uploads/, use it directly
      is_binary(post.featured_image) and String.starts_with?(post.featured_image, "/uploads/") ->
        post.featured_image
      
      # If featured_image starts with /, it's already a URL path
      is_binary(post.featured_image) and String.starts_with?(post.featured_image, "/") ->
        post.featured_image
      
      # If featured_image starts with http, it's an external URL
      is_binary(post.featured_image) and String.starts_with?(post.featured_image, "http") ->
        post.featured_image
      
      # Otherwise treat as hash filename - construct full path with user ID
      is_binary(post.featured_image) and post.user ->
        "/uploads/#{post.user.id}/blog/#{post.featured_image}"
      
      # Fallback
      true ->
        "/images/default-blog.jpg"
    end
  end

  

  def render(assigns) do
    ~H"""
    <.page_container glass={false}>
      <!-- Blog List View -->
      <div :if={@view != :post_detail}>
        <h1 class="text-4xl font-bold text-white mb-8 text-center">Our Blog</h1>

        <!-- Featured Posts Carousel -->
        <div :if={@recent_posts != []} class="mb-12">
            <h2 class="text-2xl font-bold text-white mb-6">Featured Posts</h2>

            <div class="relative glass-dark rounded-lg overflow-hidden">
              <div class="relative h-96 overflow-hidden">
                <%= for {post, index} <- Enum.with_index(@recent_posts) do %>
                  <div
                    class={[
                      "absolute inset-0 transition-transform duration-500 ease-in-out",
                      if(index == @current_slide, do: "translate-x-0",
                        else: if(index < @current_slide, do: "-translate-x-full", else: "translate-x-full")
                      )
                    ]}
                  >
                    <div class="flex h-full">
                      <!-- Image -->
                      <div class="w-1/2 relative">
                        <img src={get_featured_image_url(post, :large)}
                             alt={post.title} class="w-full h-full object-cover" />
                        <div class="absolute inset-0 bg-gradient-to-r from-transparent to-gray-800"></div>
                      </div>

                      <!-- Content -->
                      <div class="w-1/2 p-8 flex flex-col justify-center">
                        <div class="text-blue-400 text-sm mb-2">
                          <%= Calendar.strftime(post.published_at, "%B %d, %Y") %>
                        </div>
                        <h3 class="text-2xl font-bold text-white mb-4"><%= post.title %></h3>
                        <p class="text-gray-300 mb-6 line-clamp-3"><%= post.excerpt || String.slice(post.content, 0, 200) <> "..." %></p>
                        <div class="flex items-center space-x-4">
                          <.link navigate={"/blog/#{post.slug}"}
                                 class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg transition-colors">
                            Read More
                          </.link>
                          <div class="flex items-center text-gray-400 text-sm">
                            <%= if post.user.avatar_url do %>
                              <img src={post.user.avatar_url} alt={post.user.name || post.user.email} class="w-6 h-6 rounded-full mr-2 object-cover" />
                            <% else %>
                              <div class="w-6 h-6 rounded-full mr-2" style={"background-color: #{post.user.avatar_color};";}>
                                <span class="text-xs text-white flex items-center justify-center h-full">
                                  <%= String.first(post.user.name || post.user.email) %>
                                </span>
                              </div>
                            <% end %>
                            <span class="mr-4"><%= post.user.name || post.user.email %></span>
                            <span><%= Calendar.strftime(post.published_at, "%b %d, %Y") %></span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- Navigation Arrows -->
              <button phx-click="prev_slide"
                      class="absolute left-4 top-1/2 transform -translate-y-1/2 bg-black bg-opacity-50 hover:bg-opacity-75 text-white p-2 rounded-full transition-all">
                ←
              </button>
              <button phx-click="next_slide"
                      class="absolute right-4 top-1/2 transform -translate-y-1/2 bg-black bg-opacity-50 hover:bg-opacity-75 text-white p-2 rounded-full transition-all">
                →
              </button>

              <!-- Dots Indicator -->
              <div class="absolute bottom-4 left-1/2 transform -translate-x-1/2 flex space-x-2">
                <%= for {_post, index} <- Enum.with_index(@recent_posts) do %>
                  <button phx-click="go_to_slide" phx-value-slide={index}
                          class={["w-3 h-3 rounded-full transition-all",
                                  if(index == @current_slide, do: "bg-blue-500", else: "bg-gray-500 hover:bg-gray-400")]} />
                <% end %>
              </div>
            </div>
        </div>

        <!-- All Posts Grid -->
        <div class="mb-8">
            <h2 class="text-2xl font-bold text-white mb-6">All Posts</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
              <%= for post <- @posts do %>
                <article class="glass-dark rounded-lg overflow-hidden hover:transform hover:scale-105 transition-all duration-300">
                  <.link navigate={"/blog/#{post.slug}"}>
                    <img src={get_featured_image_url(post, :thumb)}
                         alt={post.title} class="w-full h-48 object-cover" />
                  </.link>

                  <div class="p-6">
                    <div class="flex items-center text-gray-400 text-sm mb-3">
                      <%= if post.user.avatar_url do %>
                        <img src={post.user.avatar_url} alt={post.user.name || post.user.email} class="w-6 h-6 rounded-full mr-2 object-cover" />
                      <% else %>
                        <div class="w-6 h-6 rounded-full mr-2" style={"background-color: #{post.user.avatar_color};";}>
                          <span class="text-xs text-white flex items-center justify-center h-full">
                            <%= String.first(post.user.name || post.user.email) %>
                          </span>
                        </div>
                      <% end %>
                      <span class="mr-4"><%= post.user.name || post.user.email %></span>
                      <span><%= Calendar.strftime(post.published_at, "%b %d, %Y") %></span>
                    </div>

                    <h3 class="text-xl font-bold text-white mb-3 hover:text-blue-400 transition-colors">
                      <.link navigate={"/blog/#{post.slug}"}><%= post.title %></.link>
                    </h3>

                    <p class="text-gray-300 mb-4 line-clamp-3">
                      <%= post.excerpt || String.slice(post.content, 0, 150) <> "..." %>
                    </p>

                    <div class="flex items-center justify-between">
                      <.link navigate={"/blog/#{post.slug}"}
                             class="text-blue-400 hover:text-blue-300 font-medium transition-colors">
                        Read More →
                      </.link>

                      <div :if={post.tags != []} class="flex flex-wrap gap-1">
                        <%= for tag <- Enum.take(post.tags, 2) do %>
                          <span class="bg-gray-700 text-gray-300 px-2 py-1 rounded text-xs">
                            #<%= tag %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </article>
              <% end %>
            </div>
          </div>
        </div>

      <!-- Blog Post Detail View -->
      <div :if={@view == :post_detail}>
        <div class="auth-glass-panel rounded-xl p-8 mb-6">
          <!-- Back button -->
          <.link navigate={~p"/blog"} class="text-blue-400 hover:text-blue-300 mb-6 inline-block">
            ← Back to Blog
          </.link>

          <!-- Featured Image -->
          <div :if={@post.featured_image} class="mb-8 rounded-lg overflow-hidden">
            <img src={get_featured_image_url(@post, :large)}
                 alt={@post.title} class="w-full h-96 object-cover" />
          </div>

          <!-- Post Header -->
          <article class="prose prose-invert max-w-none">
            <h1 class="text-4xl font-bold text-white mb-4"><%= @post.title %></h1>

            <div class="flex items-center text-gray-400 text-sm mb-8">
              <%= if @post.user.avatar_url do %>
                <img src={@post.user.avatar_url} alt={@post.user.name || @post.user.email} class="w-8 h-8 rounded-full mr-3 object-cover" />
              <% else %>
                <div class="w-8 h-8 rounded-full mr-3" style={"background-color: #{@post.user.avatar_color};";}>
                  <span class="text-sm text-white flex items-center justify-center h-full">
                    <%= String.first(@post.user.name || @post.user.email) %>
                  </span>
                </div>
              <% end %>
              <span class="mr-4"><%= @post.user.name || @post.user.email %></span>
              <span><%= Calendar.strftime(@post.published_at, "%B %d, %Y") %></span>
            </div>

            <!-- Tags -->
            <div :if={@post.tags != []} class="flex flex-wrap gap-2 mb-8">
              <%= for tag <- @post.tags do %>
                <span class="bg-gray-700 text-gray-300 px-3 py-1 rounded-full text-sm">
                  #<%= tag %>
                </span>
              <% end %>
            </div>

            <!-- Post Content -->
            <div class="text-gray-200 leading-relaxed text-lg">
              <%= PhoenixAppWeb.Markdown.render(@post.content) %>
            </div>
          </article>
        </div>
      </div>

      <script>
        setInterval(() => {
          if (window.location.pathname === '/blog') {
            const nextButton = document.querySelector('[phx-click="next_slide"]');
            if (nextButton) nextButton.click();
          }
        }, 5000);
      </script>
    </.page_container>
    """
  end
end

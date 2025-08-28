defmodule PhoenixAppWeb.BlogLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Content

  on_mount {PhoenixAppWeb.Auth, :maybe_authenticated}

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

  def handle_params(_params, _uri, socket), do: {:noreply, assign(socket, view: :post_list)}

  def handle_event("next_slide", _params, socket) do
    recent_posts = socket.assigns.recent_posts
    current = socket.assigns.current_slide
    next_slide = if current >= length(recent_posts) - 1, do: 0, else: current + 1
    {:noreply, assign(socket, current_slide: next_slide)}
  end

  def handle_event("prev_slide", _params, socket) do
    recent_posts = socket.assigns.recent_posts
    current = socket.assigns.current_slide
    prev_slide = if current <= 0, do: length(recent_posts) - 1, else: current - 1
    {:noreply, assign(socket, current_slide: prev_slide)}
  end

  def handle_event("go_to_slide", %{"slide" => slide_str}, socket) do
    slide = String.to_integer(slide_str)
    {:noreply, assign(socket, current_slide: slide)}
  end

  def render(assigns) do
    ~H"""
    <.navbar current_user={@current_user} />
    <div class="starry-background w-full">
      <div class="max-w-[80%] mx-auto px-4 py-4 relative z-10 mt-[20px]">
        <div class="stars-container">
          <div class="stars"></div>
          <div class="stars2"></div>
          <div class="stars3"></div>
        </div>
        <!-- Blog List View -->
        <div :if={@view != :post_detail}>
        <h1 class="text-4xl font-bold text-white mb-8 text-center">Our Blog</h1>

        <!-- Featured Posts Carousel -->
        <div :if={@recent_posts != []} class="mb-12">
            <h2 class="text-2xl font-bold text-white mb-6">Featured Posts</h2>

            <div class="relative bg-gray-800 rounded-lg overflow-hidden">
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
                        <img src={PhoenixApp.PostImage.url({post.featured_image, post}, :large) || "/images/default_post.png"}
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
                            <div class="w-6 h-6 rounded-full mr-2" style={"background-color: #{post.user.avatar_color};"}>
                              <span class="text-xs text-white flex items-center justify-center h-full">
                                <%= String.first(post.user.name || post.user.email) %>
                              </span>
                            </div>
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
                <article class="bg-gray-800 rounded-lg overflow-hidden hover:transform hover:scale-105 transition-all duration-300">
                  <.link navigate={"/blog/#{post.slug}"}>
                    <img src={PhoenixApp.PostImage.url({post.featured_image, post}, :thumb) || "/images/default_post.png"}
                         alt={post.title} class="w-full h-48 object-cover" />
                  </.link>

                  <div class="p-6">
                    <div class="flex items-center text-gray-400 text-sm mb-3">
                      <div class="w-6 h-6 rounded-full mr-2" style={"background-color: #{post.user.avatar_color};"}>
                        <span class="text-xs text-white flex items-center justify-center h-full">
                          <%= String.first(post.user.name || post.user.email) %>
                        </span>
                      </div>
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
    """
  end
end

defmodule PhoenixAppWeb.AdminLive.BlogManagement do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Content
  alias PhoenixApp.Content.Post

  on_mount {PhoenixAppWeb.Auth, :ensure_admin}

  def mount(_params, _session, socket) do
    posts = Content.list_posts()
    
    {:ok, assign(socket,
      posts: posts,
      page_title: "Blog Management",
      show_form: false,
      editing_post: nil,
      form: to_form(Post.changeset(%Post{}, %{}))
    )}
  end

  def handle_event("new_post", _params, socket) do
    changeset = Post.changeset(%Post{}, %{})
    
    {:noreply, assign(socket,
      show_form: true,
      editing_post: nil,
      form: to_form(changeset)
    )}
  end

  def handle_event("edit_post", %{"id" => id}, socket) do
    post = Content.get_post!(id)
    changeset = Post.changeset(post, %{})
    
    {:noreply, assign(socket,
      show_form: true,
      editing_post: post,
      form: to_form(changeset)
    )}
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket,
      show_form: false,
      editing_post: nil,
      form: to_form(Post.changeset(%Post{}, %{}))
    )}
  end

  def handle_event("validate", %{"post" => post_params}, socket) do
    post = socket.assigns.editing_post || %Post{}
    changeset = Post.changeset(post, post_params)
    
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("autosave_draft", %{"post" => post_params}, socket) do
    post = socket.assigns.editing_post || %Post{}
    # Save as draft, but do not publish
    draft_params = Map.put(post_params, "is_published", false)
    case socket.assigns.editing_post do
      nil ->
        # Create new draft
        case Content.create_post(socket.assigns.current_user, draft_params) do
          {:ok, draft_post} ->
            {:noreply, assign(socket, editing_post: draft_post, form: to_form(Post.changeset(draft_post, %{})))}
          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
      post ->
        # Update existing draft
        case Content.update_post(post, draft_params) do
          {:ok, draft_post} ->
            {:noreply, assign(socket, editing_post: draft_post, form: to_form(Post.changeset(draft_post, %{})))}
          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    # Process tags from comma-separated string to list
    processed_params = process_post_params(post_params)
    
    case socket.assigns.editing_post do
      nil ->
        # Create new post
        case Content.create_post(socket.assigns.current_user, processed_params) do
          {:ok, _post} ->
            posts = Content.list_posts()
            {:noreply, assign(socket,
              posts: posts,
              show_form: false,
              form: to_form(Post.changeset(%Post{}, %{}))
            ) |> put_flash(:info, "Post created successfully!")}
          
          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
      
      post ->
        # Update existing post
        case Content.update_post(post, processed_params) do
          {:ok, _post} ->
            posts = Content.list_posts()
            {:noreply, assign(socket,
              posts: posts,
              show_form: false,
              editing_post: nil,
              form: to_form(Post.changeset(%Post{}, %{}))
            ) |> put_flash(:info, "Post updated successfully!")}
          
          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end

  def handle_event("delete_post", %{"id" => id}, socket) do
    post = Content.get_post!(id)
    
    case Content.delete_post(post) do
      {:ok, _post} ->
        posts = Content.list_posts()
        {:noreply, assign(socket, posts: posts) |> put_flash(:info, "Post deleted successfully!")}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete post")}
    end
  end

  def handle_event("toggle_publish", %{"id" => id}, socket) do
    post = Content.get_post!(id)
    new_published_status = !post.is_published
    
    case Content.update_post(post, %{is_published: new_published_status}) do
      {:ok, _post} ->
        posts = Content.list_posts()
        status_text = if new_published_status, do: "published", else: "unpublished"
        {:noreply, assign(socket, posts: posts) |> put_flash(:info, "Post #{status_text} successfully!")}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update post")}
    end
  end

  # Helper function to process post parameters
  defp process_post_params(post_params) do
    params_with_tags = case Map.get(post_params, "tags") do
      nil -> post_params
      "" -> Map.put(post_params, "tags", [])
      tags_string when is_binary(tags_string) ->
        tags_list = 
          tags_string
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
        Map.put(post_params, "tags", tags_list)
      tags_list when is_list(tags_list) -> post_params
    end
    
    # Convert is_published string to boolean
    case Map.get(params_with_tags, "is_published") do
      "true" -> Map.put(params_with_tags, "is_published", true)
      "false" -> Map.put(params_with_tags, "is_published", false)
      true -> params_with_tags
      false -> params_with_tags
      nil -> Map.put(params_with_tags, "is_published", false)
      _ -> Map.put(params_with_tags, "is_published", false)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="starry-background min-h-screen overflow-y-auto">
      <div class="stars-container fixed inset-0 pointer-events-none">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <.navbar current_user={@current_user} />
      
      <div class="content-area w-full max-w-[90%] mx-auto px-4 py-8 relative z-10 min-h-screen">
        <div class="max-w-6xl mx-auto">
          <div class="flex justify-between items-center mb-8">
            <h1 class="text-3xl font-bold text-white">Blog Management</h1>
            <button phx-click="new_post" class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg transition-colors">
              ✍️ New Post
            </button>
          </div>

          <!-- Blog Post Form -->
          <%= if @show_form do %>
            <div class="bg-gray-800 rounded-lg p-6 mb-8">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-semibold text-white">
                  <%= if @editing_post, do: "Edit Post", else: "Create New Post" %>
                </h2>
                <button phx-click="cancel_form" class="text-gray-400 hover:text-white">
                  ✕
                </button>
              </div>

              <.form for={@form} phx-submit="save" phx-change="validate" phx-debounce="500" id="blog-post-form" autocomplete="off" class="space-y-4"
                phx-hook="BlogAutosave">
                <style>
                  #blog-post-form input, #blog-post-form textarea, #blog-post-form select {
                    background-color: #374151 !important;
                    color: #ffffff !important;
                    border-color: #4b5563 !important;
                  }
                  #blog-post-form input:focus, #blog-post-form textarea:focus, #blog-post-form select:focus {
                    border-color: #3b82f6 !important;
                    box-shadow: 0 0 0 1px #3b82f6 !important;
                  }
                  #blog-post-form label {
                    color: #d1d5db !important;
                  }
                </style>
                
                <div>
                  <.input field={@form[:title]} label="Title" placeholder="Enter post title..." autocomplete="off" />
                </div>

                <div>
                  <.input field={@form[:slug]} label="Slug (URL)" placeholder="auto-generated-from-title" autocomplete="off" />
                </div>

                <div>
                  <.input field={@form[:excerpt]} type="textarea" label="Excerpt" placeholder="Brief description of the post..." rows="3" autocomplete="off" />
                </div>

                <div>
                  <.input field={@form[:content]} type="textarea" label="Content" placeholder="Write your post content here... (Supports Markdown)" rows="15" autocomplete="off" />
                  <div class="text-xs text-gray-400 mt-1">Supports Markdown formatting</div>
                </div>

                <div>
                  <.input field={@form[:meta_description]} label="Meta Description" placeholder="SEO description (max 160 characters)" autocomplete="off" />
                </div>

                <div>
                  <.input field={@form[:tags]} label="Tags" placeholder="tag1, tag2, tag3" autocomplete="off" />
                  <div class="text-xs text-gray-400 mt-1">Separate tags with commas</div>
                </div>

                <div class="flex items-center space-x-4">
                  <div>
                    <.input field={@form[:is_published]} type="select" label="Status" options={[
                      {"Draft", false},
                      {"Published", true}
                    ]} />
                  </div>
                  
                  <div>
                    <.input field={@form[:post_type]} type="select" label="Post Type" options={[
                      {"Blog Post", "post"},
                      {"Page", "page"}
                    ]} />
                  </div>
                </div>

                <div class="mt-6">
                  <div class="flex space-x-4">
                    <button type="submit" class="bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded-lg transition-colors font-medium">
                      <%= if @editing_post, do: "Update Post", else: "Create Post" %>
                    </button>
                    <button type="button" phx-click="cancel_form" class="bg-gray-600 hover:bg-gray-700 text-white px-6 py-2 rounded-lg transition-colors font-medium">
                      Cancel
                    </button>
                  </div>
                  <div class="mt-2 text-xs text-gray-400">Drafts are autosaved every 10 seconds.</div>
                </div>
              </.form>
            </div>
          <% end %>

          <!-- Posts List -->
          <div class="bg-gray-800 rounded-lg overflow-hidden">
            <div class="px-6 py-4 border-b border-gray-700">
              <h2 class="text-lg font-semibold text-white">All Posts (<%= length(@posts) %>)</h2>
            </div>

            <%= if @posts == [] do %>
              <div class="p-8 text-center text-gray-400">
                <div class="text-4xl mb-4">📝</div>
                <div class="text-lg mb-2">No posts yet</div>
                <div class="text-sm">Create your first blog post to get started!</div>
              </div>
            <% else %>
              <div class="divide-y divide-gray-700">
                <%= for post <- @posts do %>
                  <div class="p-6 hover:bg-gray-750 transition-colors">
                    <div class="flex justify-between items-start">
                      <div class="flex-1">
                        <div class="flex items-center space-x-3 mb-2">
                          <h3 class="text-lg font-medium text-white"><%= post.title %></h3>
                          <span class={["px-2 py-1 text-xs rounded-full",
                                       if post.is_published do
                                         "bg-green-600 text-white"
                                       else
                                         "bg-gray-600 text-gray-300"
                                       end]}>
                            <%= if post.is_published, do: "Published", else: "Draft" %>
                          </span>
                        </div>
                        
                        <div class="text-sm text-gray-400 mb-2">
                          By <%= post.user.name || post.user.email %> • 
                          <%= Calendar.strftime(post.inserted_at, "%B %d, %Y") %>
                          <%= if post.published_at do %>
                            • Published <%= Calendar.strftime(post.published_at, "%B %d, %Y") %>
                          <% end %>
                        </div>

                        <%= if post.excerpt do %>
                          <p class="text-gray-300 text-sm mb-3"><%= post.excerpt %></p>
                        <% end %>

                        <%= if post.tags && length(post.tags) > 0 do %>
                          <div class="flex flex-wrap gap-1 mb-3">
                            <%= for tag <- post.tags do %>
                              <span class="bg-blue-600 text-white px-2 py-1 text-xs rounded">
                                <%= tag %>
                              </span>
                            <% end %>
                          </div>
                        <% end %>

                        <div class="text-xs text-gray-500">
                          Slug: /<%= post.slug %>
                        </div>
                      </div>

                      <div class="flex space-x-2 ml-4">
                        <button phx-click="toggle_publish" phx-value-id={post.id}
                                class={["px-3 py-1 text-sm rounded transition-colors",
                                       if(post.is_published, do: "bg-orange-600 hover:bg-orange-700 text-white", else: "bg-green-600 hover:bg-green-700 text-white")]}>
                          <%= if post.is_published, do: "Unpublish", else: "Publish" %>
                        </button>
                        
                        <button phx-click="edit_post" phx-value-id={post.id}
                                class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 text-sm rounded transition-colors">
                          Edit
                        </button>
                        
                        <button phx-click="delete_post" phx-value-id={post.id}
                                data-confirm="Are you sure you want to delete this post?"
                                class="bg-red-600 hover:bg-red-700 text-white px-3 py-1 text-sm rounded transition-colors">
                          Delete
                        </button>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
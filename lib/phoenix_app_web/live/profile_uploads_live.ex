defmodule PhoenixAppWeb.ProfileUploadsLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.{Repo, Content.UserMedia}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    {:ok, 
     socket
     |> assign(
       page_title: "My Uploads",
       filter: "all",
       sort_by: "date_desc",
       uploads: list_user_uploads(user),
       selected_ids: MapSet.new(),
       show_delete_confirm: false
     )}
  end

  @impl true
  def handle_event("filter", %{"type" => filter}, socket) do
    {:noreply, assign(socket, filter: filter, uploads: list_user_uploads(socket.assigns.current_user, filter))}
  end

  def handle_event("sort", %{"by" => sort_by}, socket) do
    uploads = socket.assigns.uploads |> sort_uploads(sort_by)
    {:noreply, assign(socket, sort_by: sort_by, uploads: uploads)}
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected_ids = 
      if MapSet.member?(socket.assigns.selected_ids, id) do
        MapSet.delete(socket.assigns.selected_ids, id)
      else
        MapSet.put(socket.assigns.selected_ids, id)
      end
    
    {:noreply, assign(socket, selected_ids: selected_ids)}
  end

  def handle_event("select_all", _, socket) do
    all_ids = Enum.map(socket.assigns.uploads, & &1.id) |> MapSet.new()
    {:noreply, assign(socket, selected_ids: all_ids)}
  end

  def handle_event("deselect_all", _, socket) do
    {:noreply, assign(socket, selected_ids: MapSet.new())}
  end

  def handle_event("show_delete_confirm", _, socket) do
    if MapSet.size(socket.assigns.selected_ids) > 0 do
      {:noreply, assign(socket, show_delete_confirm: true)}
    else
      {:noreply, put_flash(socket, :error, "No files selected")}
    end
  end

  def handle_event("cancel_delete", _, socket) do
    {:noreply, assign(socket, show_delete_confirm: false)}
  end

  def handle_event("confirm_delete", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_ids)
    user = socket.assigns.current_user
    
    # Delete files and records
    case delete_uploads(selected_ids, user) do
      {:ok, count} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Successfully deleted #{count} file(s)")
         |> assign(
           uploads: list_user_uploads(user),
           selected_ids: MapSet.new(),
           show_delete_confirm: false
         )}
      {:error, reason} ->
        {:noreply, 
         socket
         |> put_flash(:error, "Failed to delete files: #{reason}")
         |> assign(show_delete_confirm: false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div data-responsive-content class="min-h-screen pointer-events-none" style="padding-top: 30px; padding-bottom: 48px;">
      <div class="max-w-7xl mx-auto px-4 py-8 pointer-events-auto">
        <div class="auth-glass-panel p-8 rounded-xl">
          <!-- Header -->
          <div class="mb-8">
            <h1 class="text-3xl font-bold text-white mb-2">My Uploads</h1>
            <p class="text-gray-400">Manage your uploaded files</p>
          </div>

          <!-- Storage Info -->
          <div class="mb-6 p-4 bg-gray-700/50 rounded-lg">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm text-gray-300">Storage Used</span>
              <span class="text-sm font-medium text-white">
                <%= format_storage_size(total_storage_used(@uploads)) %> / 1 GB
              </span>
            </div>
            <div class="w-full bg-gray-600 rounded-full h-2">
              <div class="bg-blue-500 h-2 rounded-full transition-all" style={"width: #{storage_percentage(@uploads)}%"}></div>
            </div>
          </div>

          <!-- Controls -->
          <div class="flex flex-wrap items-center justify-between gap-4 mb-6">
            <!-- Filters -->
            <div class="flex items-center space-x-2">
              <button phx-click="filter" phx-value-type="all" class={"px-4 py-2 rounded transition-colors #{if @filter == "all", do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}>
                All
              </button>
              <button phx-click="filter" phx-value-type="image" class={"px-4 py-2 rounded transition-colors #{if @filter == "image", do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}>
                Images
              </button>
              <button phx-click="filter" phx-value-type="video" class={"px-4 py-2 rounded transition-colors #{if @filter == "video", do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}>
                Videos
              </button>
              <button phx-click="filter" phx-value-type="audio" class={"px-4 py-2 rounded transition-colors #{if @filter == "audio", do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}>
                Audio
              </button>
              <button phx-click="filter" phx-value-type="other" class={"px-4 py-2 rounded transition-colors #{if @filter == "other", do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}>
                Other
              </button>
            </div>

            <!-- Sort and Actions -->
            <div class="flex items-center space-x-2">
              <select phx-change="sort" name="by" class="bg-gray-700 text-white px-4 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none">
                <option value="date_desc" selected={@sort_by == "date_desc"}>Newest First</option>
                <option value="date_asc" selected={@sort_by == "date_asc"}>Oldest First</option>
                <option value="size_desc" selected={@sort_by == "size_desc"}>Largest First</option>
                <option value="size_asc" selected={@sort_by == "size_asc"}>Smallest First</option>
                <option value="name_asc" selected={@sort_by == "name_asc"}>Name A-Z</option>
              </select>

              <%= if MapSet.size(@selected_ids) > 0 do %>
                <button phx-click="show_delete_confirm" class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded transition-colors">
                  Delete Selected (<%= MapSet.size(@selected_ids) %>)
                </button>
                <button phx-click="deselect_all" class="bg-gray-600 hover:bg-gray-500 text-white px-4 py-2 rounded transition-colors">
                  Deselect All
                </button>
              <% else %>
                <button phx-click="select_all" class="bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded transition-colors">
                  Select All
                </button>
              <% end %>
            </div>
          </div>

          <!-- Uploads Grid -->
          <%= if length(@uploads) == 0 do %>
            <div class="text-center py-12">
              <svg class="mx-auto h-12 w-12 text-gray-500 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
              </svg>
              <p class="text-gray-400 text-lg">No uploads yet</p>
              <p class="text-gray-500 text-sm mt-2">Files you upload in the forum will appear here</p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              <%= for upload <- @uploads do %>
                <div class={"relative group bg-gray-700/50 rounded-lg overflow-hidden border-2 transition-all #{if MapSet.member?(@selected_ids, upload.id), do: "border-blue-500", else: "border-transparent hover:border-gray-500"}"}>
                  <!-- Checkbox -->
                  <div class="absolute top-2 left-2 z-10">
                    <input 
                      type="checkbox" 
                      checked={MapSet.member?(@selected_ids, upload.id)}
                      phx-click="toggle_select" 
                      phx-value-id={upload.id}
                      class="w-5 h-5 rounded border-gray-300 text-blue-600 focus:ring-blue-500 cursor-pointer"
                    />
                  </div>

                  <!-- Preview -->
                  <div class="aspect-square bg-gray-800 flex items-center justify-center p-4">
                    <%= case detect_type(upload) do %>
                      <% :image -> %>
                        <img src={upload.url} alt={upload.filename} class="max-w-full max-h-full object-contain" />
                      <% :video -> %>
                        <svg class="w-16 h-16 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
                        </svg>
                      <% :audio -> %>
                        <svg class="w-16 h-16 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
                        </svg>
                      <% _ -> %>
                        <svg class="w-16 h-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"></path>
                        </svg>
                    <% end %>
                  </div>

                  <!-- Info -->
                  <div class="p-3">
                    <p class="text-sm text-white font-medium truncate mb-1" title={upload.filename}>
                      <%= upload.filename %>
                    </p>
                    <div class="flex items-center justify-between text-xs text-gray-400">
                      <span><%= format_file_size(upload.file_size) %></span>
                      <span><%= relative_time(upload.inserted_at) %></span>
                    </div>
                    <%!-- Usage info would go here if we track it --%>
                  </div>

                  <!-- Actions (on hover) -->
                  <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center space-x-2">
                    <a href={upload.url} target="_blank" class="bg-blue-600 hover:bg-blue-700 text-white p-2 rounded" title="View">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                      </svg>
                    </a>
                    <a href={upload.url} download class="bg-green-600 hover:bg-green-700 text-white p-2 rounded" title="Download">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                      </svg>
                    </a>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <%!-- Delete Confirmation Modal --%>
    <%= if @show_delete_confirm do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" phx-click="cancel_delete">
        <div class="bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4" phx-click="stop_propagation">
          <h3 class="text-xl font-bold text-white mb-4">Confirm Deletion</h3>
          <p class="text-gray-300 mb-6">
            Are you sure you want to delete <%= MapSet.size(@selected_ids) %> file(s)? This action cannot be undone.
          </p>
          <div class="flex justify-end space-x-3">
            <button phx-click="cancel_delete" class="px-4 py-2 bg-gray-600 hover:bg-gray-500 text-white rounded transition-colors">
              Cancel
            </button>
            <button phx-click="confirm_delete" class="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded transition-colors">
              Delete
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # Private helper functions
  defp list_user_uploads(user, filter \\ "all") do
    base_query = from(m in UserMedia,
      where: m.user_id == ^user.id,
      order_by: [desc: m.inserted_at]
    )

    query = case filter do
      "image" -> from(m in base_query, where: m.file_type == "image")
      "video" -> from(m in base_query, where: m.file_type == "video")
      "audio" -> from(m in base_query, where: m.file_type == "audio")
      "other" -> from(m in base_query, where: m.file_type not in ["image", "video", "audio"])
      _ -> base_query
    end

    Repo.all(query)
  end

  defp sort_uploads(uploads, "date_asc"), do: Enum.sort_by(uploads, & &1.inserted_at)
  defp sort_uploads(uploads, "date_desc"), do: Enum.sort_by(uploads, & &1.inserted_at, :desc)
  defp sort_uploads(uploads, "size_asc"), do: Enum.sort_by(uploads, & &1.file_size)
  defp sort_uploads(uploads, "size_desc"), do: Enum.sort_by(uploads, & &1.file_size, :desc)
  defp sort_uploads(uploads, "name_asc"), do: Enum.sort_by(uploads, & &1.filename)
  defp sort_uploads(uploads, _), do: uploads

  defp delete_uploads(ids, user) do
    media_items = Repo.all(from m in UserMedia, where: m.id in ^ids and m.user_id == ^user.id)
    
    # Delete files from filesystem
    Enum.each(media_items, fn media ->
      if media.file_path do
        File.rm(media.file_path)
      end
    end)

    # Delete database records
    {count, _} = Repo.delete_all(from m in UserMedia, where: m.id in ^ids and m.user_id == ^user.id)
    
    {:ok, count}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp total_storage_used(uploads) do
    Enum.reduce(uploads, 0, fn upload, acc -> acc + (upload.file_size || 0) end)
  end

  defp storage_percentage(uploads) do
    used = total_storage_used(uploads)
    limit = 1_073_741_824  # 1 GB
    min(round(used / limit * 100), 100)
  end

  defp format_storage_size(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_file_size(_), do: "Unknown"

  defp detect_type(upload) do
    file_type = upload.file_type || ""
    case file_type do
      "image" -> :image
      "video" -> :video
      "audio" -> :audio
      _ -> :file
    end
  end

  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end
end

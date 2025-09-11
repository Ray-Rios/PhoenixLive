defmodule PhoenixAppWeb.FilesLive do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Files

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    if user do
      files = Files.list_user_files(user)
      stats = Files.get_file_stats(user)
      
      {:ok, assign(socket,
        files: files,
        stats: stats,
        selected_files: MapSet.new(),
        view_mode: :grid,
        search_query: "",
        page_title: "Files",
        preview_file: nil,
        uploading_files: [],
        upload_progress: %{},
        show_create_folder_modal: false,
        show_rename_modal: false,
        rename_file_id: nil
      )}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_params(%{"view" => "upload"}, _uri, socket) do
    {:noreply, assign(socket, view: :upload)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, view: :list)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    user = socket.assigns.current_user
    
    files = if query == "" do
      Files.list_user_files(user)
    else
      Files.search_files(user, query)
    end
    
    {:noreply, assign(socket, files: files, search_query: query)}
  end

  def handle_event("toggle_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, view_mode: String.to_atom(mode))}
  end

  def handle_event("select_file", %{"file_id" => file_id}, socket) do
    selected = socket.assigns.selected_files
    
    new_selected = if MapSet.member?(selected, file_id) do
      MapSet.delete(selected, file_id)
    else
      MapSet.put(selected, file_id)
    end
    
    {:noreply, assign(socket, selected_files: new_selected)}
  end

  def handle_event("select_all", _params, socket) do
    all_file_ids = Enum.map(socket.assigns.files, &(&1.id)) |> MapSet.new()
    {:noreply, assign(socket, selected_files: all_file_ids)}
  end

  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, selected_files: MapSet.new())}
  end

  def handle_event("delete_selected", _params, socket) do
    user = socket.assigns.current_user
    selected_ids = MapSet.to_list(socket.assigns.selected_files)
    
    Enum.each(selected_ids, fn file_id ->
      file = Files.get_user_file!(user, file_id)
      Files.delete_user_file(file)
    end)
    
    files = Files.list_user_files(user)
    stats = Files.get_file_stats(user)
    
    {:noreply, assign(socket,
      files: files,
      stats: stats,
      selected_files: MapSet.new()
    ) |> put_flash(:info, "#{length(selected_ids)} file(s) deleted")}
  end

  def handle_event("drag_over", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("drag_leave", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("file_drop", %{"files" => files}, socket) when is_list(files) do
    user = socket.assigns.current_user
    
    # Process multiple files
    results = Enum.map(files, fn file_data ->
      Files.create_user_file(user, file_data)
    end)
    
    success_count = Enum.count(results, fn {status, _} -> status == :ok end)
    error_count = Enum.count(results, fn {status, _} -> status == :error end)
    
    files = Files.list_user_files(user)
    stats = Files.get_file_stats(user)
    
    message = cond do
      error_count == 0 -> "#{success_count} file(s) uploaded successfully"
      success_count == 0 -> "Failed to upload #{error_count} file(s)"
      true -> "#{success_count} file(s) uploaded, #{error_count} failed"
    end
    
    flash_type = if error_count == 0, do: :info, else: :error
    
    {:noreply, assign(socket,
      files: files,
      stats: stats,
      uploading_files: [],
      upload_progress: %{}
    ) |> put_flash(flash_type, message)}
  end

  def handle_event("file_selected", file_data, socket) do
    user = socket.assigns.current_user
    
    case Files.create_user_file(user, file_data) do
      {:ok, _file} ->
        files = Files.list_user_files(user)
        stats = Files.get_file_stats(user)
        
        {:noreply, assign(socket,
          files: files,
          stats: stats
        ) |> put_flash(:info, "File uploaded successfully")}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to upload file")}
    end
  end

  def handle_event("show_create_folder_modal", _params, socket) do
    {:noreply, assign(socket, show_create_folder_modal: true)}
  end

  def handle_event("hide_create_folder_modal", _params, socket) do
    {:noreply, assign(socket, show_create_folder_modal: false)}
  end

  def handle_event("create_folder", %{"name" => folder_name}, socket) do
    user = socket.assigns.current_user
    
    case Files.create_folder(user, folder_name) do
      {:ok, _folder} ->
        files = Files.list_user_files(user)
        stats = Files.get_file_stats(user)
        
        {:noreply, assign(socket,
          files: files,
          stats: stats,
          show_create_folder_modal: false
        ) |> put_flash(:info, "Folder '#{folder_name}' created successfully")}
      
      {:error, _changeset} ->
        {:noreply, assign(socket, show_create_folder_modal: false) |> put_flash(:error, "Failed to create folder")}
    end
  end

  def handle_event("show_rename_modal", %{"file_id" => file_id}, socket) do
    {:noreply, assign(socket, show_rename_modal: true, rename_file_id: file_id)}
  end

  def handle_event("hide_rename_modal", _params, socket) do
    {:noreply, assign(socket, show_rename_modal: false, rename_file_id: nil)}
  end

  def handle_event("rename_file", %{"file_id" => file_id, "new_name" => new_name}, socket) do
    user = socket.assigns.current_user
    file = Files.get_user_file!(user, file_id)
    
    case Files.update_user_file(file, %{original_filename: new_name}) do
      {:ok, _file} ->
        files = Files.list_user_files(user)
        
        {:noreply, assign(socket, files: files, show_rename_modal: false, rename_file_id: nil) |> put_flash(:info, "File renamed successfully")}
      
      {:error, _changeset} ->
        {:noreply, assign(socket, show_rename_modal: false, rename_file_id: nil) |> put_flash(:error, "Failed to rename file")}
    end
  end

  def handle_event("delete_file", %{"file_id" => file_id}, socket) do
    user = socket.assigns.current_user
    file = Files.get_user_file!(user, file_id)
    
    case Files.delete_user_file(file) do
      {:ok, _file} ->
        files = Files.list_user_files(user)
        stats = Files.get_file_stats(user)
        
        {:noreply, assign(socket,
          files: files,
          stats: stats
        ) |> put_flash(:info, "File deleted successfully")}
      
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete file")}
    end
  end

  def handle_event("download_file", %{"file_id" => file_id}, socket) do
    user = socket.assigns.current_user
    file = Files.get_user_file!(user, file_id)
    
    {:noreply, push_event(socket, "download-file", %{
      url: PhoenixApp.UserFileUpload.url({file.file, file}),
      filename: file.original_filename
    })}
  end

  def handle_event("preview_file", %{"file_id" => file_id}, socket) do
    user = socket.assigns.current_user
    file = Files.get_user_file!(user, file_id)
    
    {:noreply, assign(socket, preview_file: file)}
  end

  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, preview_file: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="starry-background min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-indigo-900"
         phx-hook="FileDragDrop" id="file-manager">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <div class="container mx-auto px-4 py-8 relative z-10">
        <!-- Header -->
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold text-white">📁 File Manager</h1>
          <div class="flex items-center space-x-4">
            <button phx-click="show_create_folder_modal"
                    class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg transition-colors">
              📁 New Folder
            </button>
            <label for="file-upload" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors cursor-pointer">
              📤 Upload Files
            </label>
            <input type="file" multiple id="file-upload" class="hidden" phx-hook="FileUpload" />
          </div>
        </div>

        <!-- Stats Dashboard -->
        <div class="grid grid-cols-2 md:grid-cols-6 gap-4 mb-8">
          <div class="bg-gray-800 rounded-lg p-4 text-center">
            <div class="text-2xl font-bold text-white"><%= @stats.total_files %></div>
            <div class="text-gray-400 text-sm">Total Files</div>
          </div>
          <div class="bg-gray-800 rounded-lg p-4 text-center">
            <div class="text-2xl font-bold text-blue-400"><%= @stats.images %></div>
            <div class="text-gray-400 text-sm">🖼️ Images</div>
          </div>
          <div class="bg-gray-800 rounded-lg p-4 text-center">
            <div class="text-2xl font-bold text-green-400"><%= @stats.videos %></div>
            <div class="text-gray-400 text-sm">🎥 Videos</div>
          </div>
          <div class="bg-gray-800 rounded-lg p-4 text-center">
            <div class="text-2xl font-bold text-purple-400"><%= @stats.audio %></div>
            <div class="text-gray-400 text-sm">🎵 Audio</div>
          </div>
          <div class="bg-gray-800 rounded-lg p-4 text-center">
            <div class="text-2xl font-bold text-yellow-400"><%= @stats.documents %></div>
            <div class="text-gray-400 text-sm">📄 Docs</div>
          </div>
          <div class="bg-gray-800 rounded-lg p-4 text-center">
            <div class="text-2xl font-bold text-red-400"><%= format_file_size(@stats.total_size) %></div>
            <div class="text-gray-400 text-sm">💾 Storage</div>
          </div>
        </div>

        <!-- Controls Bar -->
        <div class="bg-gray-800 rounded-lg p-4 mb-6">
          <div class="flex flex-wrap justify-between items-center gap-4">
            <!-- Search -->
            <form phx-change="search" class="flex items-center">
              <div class="relative">
                <input type="text" name="query" value={@search_query} placeholder="🔍 Search files..." 
                       class="bg-gray-700 text-white px-4 py-2 pl-10 rounded-lg w-64 focus:ring-2 focus:ring-blue-500" />
                <div class="absolute left-3 top-2.5 text-gray-400">🔍</div>
              </div>
            </form>
            
            <!-- View Mode Toggle -->
            <div class="flex bg-gray-700 rounded-lg p-1">
              <button phx-click="toggle_view" phx-value-mode="grid"
                      class={["px-4 py-2 rounded text-sm transition-colors",
                             if(@view_mode == :grid, do: "bg-blue-600 text-white", else: "text-gray-300 hover:text-white")]}>
                🔲 Grid
              </button>
              <button phx-click="toggle_view" phx-value-mode="list"
                      class={["px-4 py-2 rounded text-sm transition-colors",
                             if(@view_mode == :list, do: "bg-blue-600 text-white", else: "text-gray-300 hover:text-white")]}>
                📋 List
              </button>
            </div>

            <!-- Selection Actions -->
            <div class="flex items-center space-x-2">
              <%= if MapSet.size(@selected_files) > 0 do %>
                <span class="text-gray-300 text-sm"><%= MapSet.size(@selected_files) %> selected</span>
                <button phx-click="delete_selected" 
                        class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm transition-colors"
                        onclick="return confirm('Are you sure you want to delete the selected files?')">
                  🗑️ Delete
                </button>
                <button phx-click="deselect_all" class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg text-sm transition-colors">
                  ❌ Deselect
                </button>
              <% else %>
                <%= if @files != [] do %>
                  <button phx-click="select_all" class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg text-sm transition-colors">
                    ☑️ Select All
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Drag & Drop Zone -->
        <div id="drop-zone" class="border-2 border-dashed border-gray-600 rounded-lg p-8 mb-6 text-center transition-colors hover:border-blue-500 hover:bg-gray-800/50">
          <div class="text-4xl text-gray-400 mb-4">📁</div>
          <div class="text-xl text-white mb-2">Drag & Drop Files Here</div>
          <div class="text-gray-400">Or click "Upload Files" button above • Max 50MB per file</div>
        </div>

        <!-- Files Grid View -->
        <div :if={@view_mode == :grid} class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
          <%= for file <- @files do %>
            <div class={["bg-gray-800 rounded-lg p-4 hover:bg-gray-700 transition-colors cursor-pointer relative group",
                        if(MapSet.member?(@selected_files, file.id), do: "ring-2 ring-blue-500 bg-blue-900/30")]}
                 phx-click="select_file" phx-value-file_id={file.id}>
              
              <!-- File Preview -->
              <div class="text-center mb-3">
                <%= cond do %>
                  <% is_image?(file) -> %>
                    <img src={get_file_url(file)} alt={file.original_filename} 
                         class="w-16 h-16 object-cover rounded mx-auto mb-2" />
                  <% is_video?(file) -> %>
                    <div class="text-4xl text-green-400 mb-2">🎥</div>
                  <% is_audio?(file) -> %>
                    <div class="text-4xl text-purple-400 mb-2">🎵</div>
                  <% is_document?(file) -> %>
                    <div class="text-4xl text-yellow-400 mb-2">📄</div>
                  <% true -> %>
                    <div class="text-4xl text-gray-400 mb-2">📁</div>
                <% end %>
              </div>
              
              <!-- File Info -->
              <div class="text-white text-sm font-medium truncate mb-1"><%= file.original_filename %></div>
              <div class="text-gray-400 text-xs"><%= format_file_size(file.file_size) %></div>
              
              <!-- Action Buttons (Show on Hover) -->
              <div class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                <div class="flex space-x-1">
                  <button phx-click="preview_file" phx-value-file_id={file.id}
                          class="bg-blue-600 hover:bg-blue-700 text-white p-1 rounded text-xs">
                    👁️
                  </button>
                  <button phx-click="download_file" phx-value-file_id={file.id}
                          class="bg-green-600 hover:bg-green-700 text-white p-1 rounded text-xs">
                    ⬇️
                  </button>
                  <button phx-click="delete_file" phx-value-file_id={file.id}
                          class="bg-red-600 hover:bg-red-700 text-white p-1 rounded text-xs"
                          onclick="return confirm('Delete this file?')">
                    🗑️
                  </button>
                </div>
              </div>
              
              <!-- Selection Checkbox -->
              <div class="absolute top-2 left-2">
                <input type="checkbox" checked={MapSet.member?(@selected_files, file.id)}
                       class="rounded bg-gray-600 border-gray-500" />
              </div>
            </div>
          <% end %>
        </div>

        <!-- Files List View -->
        <div :if={@view_mode == :list} class="bg-gray-800 rounded-lg overflow-hidden">
          <table class="w-full">
            <thead class="bg-gray-700">
              <tr>
                <th class="px-4 py-3 text-left text-white w-8">
                  <input type="checkbox" class="rounded bg-gray-600 border-gray-500" />
                </th>
                <th class="px-4 py-3 text-left text-white">📄 Name</th>
                <th class="px-4 py-3 text-left text-white">🏷️ Type</th>
                <th class="px-4 py-3 text-left text-white">📏 Size</th>
                <th class="px-4 py-3 text-left text-white">📅 Modified</th>
                <th class="px-4 py-3 text-left text-white">⚙️ Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for file <- @files do %>
                <tr class={["border-b border-gray-700 hover:bg-gray-700 transition-colors",
                           if(MapSet.member?(@selected_files, file.id), do: "bg-blue-900/30")]}>
                  <td class="px-4 py-3">
                    <input type="checkbox" checked={MapSet.member?(@selected_files, file.id)}
                           phx-click="select_file" phx-value-file_id={file.id}
                           class="rounded bg-gray-600 border-gray-500" />
                  </td>
                  <td class="px-4 py-3">
                    <div class="flex items-center space-x-3">
                      <%= cond do %>
                        <% is_image?(file) -> %>
                          <img src={get_file_url(file)} alt="" class="w-8 h-8 object-cover rounded" />
                        <% is_video?(file) -> %>
                          <div class="text-green-400">🎥</div>
                        <% is_audio?(file) -> %>
                          <div class="text-purple-400">🎵</div>
                        <% is_document?(file) -> %>
                          <div class="text-yellow-400">📄</div>
                        <% true -> %>
                          <div class="text-gray-400">📁</div>
                      <% end %>
                      <span class="text-white"><%= file.original_filename %></span>
                    </div>
                  </td>
                  <td class="px-4 py-3 text-gray-300"><%= file.content_type %></td>
                  <td class="px-4 py-3 text-gray-300"><%= format_file_size(file.file_size) %></td>
                  <td class="px-4 py-3 text-gray-300"><%= Calendar.strftime(file.updated_at, "%m/%d/%Y %H:%M") %></td>
                  <td class="px-4 py-3">
                    <div class="flex space-x-2">
                      <button phx-click="preview_file" phx-value-file_id={file.id}
                              class="text-blue-400 hover:text-blue-300 text-sm">👁️ Preview</button>
                      <button phx-click="download_file" phx-value-file_id={file.id}
                              class="text-green-400 hover:text-green-300 text-sm">⬇️ Download</button>
                      <button phx-click="show_rename_modal" phx-value-file_id={file.id}
                              class="text-yellow-400 hover:text-yellow-300 text-sm">✏️ Rename</button>
                      <button phx-click="delete_file" phx-value-file_id={file.id}
                              class="text-red-400 hover:text-red-300 text-sm"
                              onclick="return confirm('Delete this file?')">🗑️ Delete</button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <!-- Empty State -->
        <div :if={@files == []} class="text-center py-16">
          <div class="text-6xl text-gray-400 mb-4">📁</div>
          <div class="text-gray-400 text-xl mb-2">No files found</div>
          <p class="text-gray-500 mb-6">Drag & drop files above or click "Upload Files" to get started</p>
          <div class="text-sm text-gray-400">
            <p><strong>Supported formats:</strong></p>
            <p>Images: JPG, PNG, GIF, WebP • Documents: PDF, DOC, DOCX, TXT</p>
            <p>Media: MP3, MP4, AVI, MOV • Archives: ZIP, RAR</p>
          </div>
        </div>

        <!-- File Preview Modal -->
        <div :if={@preview_file} class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50"
             phx-click="close_preview">
          <div class="max-w-4xl max-h-full p-4" phx-click-away="close_preview">
            <div class="bg-gray-800 rounded-lg p-6">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-white font-semibold text-lg">📄 <%= @preview_file.original_filename %></h3>
                <button phx-click="close_preview" class="text-gray-400 hover:text-white text-2xl">✕</button>
              </div>
              
              <%= cond do %>
                <% is_image?(@preview_file) -> %>
                  <img src={get_file_url(@preview_file)} 
                       alt={@preview_file.original_filename} class="max-w-full max-h-96 mx-auto rounded" />
                <% is_video?(@preview_file) -> %>
                  <video controls class="max-w-full max-h-96 mx-auto rounded">
                    <source src={get_file_url(@preview_file)} type={@preview_file.content_type} />
                  </video>
                <% is_audio?(@preview_file) -> %>
                  <div class="text-center py-8">
                    <div class="text-6xl text-purple-400 mb-4">🎵</div>
                    <audio controls class="mx-auto">
                      <source src={get_file_url(@preview_file)} type={@preview_file.content_type} />
                    </audio>
                  </div>
                <% true -> %>
                  <div class="text-center text-gray-400 py-8">
                    <div class="text-6xl mb-4">📄</div>
                    <p>Preview not available for this file type</p>
                    <button phx-click="download_file" phx-value-file_id={@preview_file.id}
                            class="mt-4 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg">
                      ⬇️ Download File
                    </button>
                  </div>
              <% end %>
              
              <!-- File Details -->
              <div class="mt-4 pt-4 border-t border-gray-600 text-sm text-gray-300">
                <div class="grid grid-cols-2 gap-4">
                  <div><strong>Size:</strong> <%= format_file_size(@preview_file.file_size) %></div>
                  <div><strong>Type:</strong> <%= @preview_file.content_type %></div>
                  <div><strong>Uploaded:</strong> <%= Calendar.strftime(@preview_file.inserted_at, "%m/%d/%Y %H:%M") %></div>
                  <div><strong>Modified:</strong> <%= Calendar.strftime(@preview_file.updated_at, "%m/%d/%Y %H:%M") %></div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Create Folder Modal -->
        <div :if={@show_create_folder_modal} class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50"
             phx-click="hide_create_folder_modal">
          <div class="bg-gray-800 rounded-lg p-6 w-96" phx-click-away="hide_create_folder_modal">
            <h3 class="text-white font-semibold text-lg mb-4">📁 Create New Folder</h3>
            <form phx-submit="create_folder">
              <input type="text" name="name" placeholder="Folder name" required
                     class="w-full bg-gray-700 text-white px-4 py-2 rounded-lg mb-4 focus:ring-2 focus:ring-blue-500" />
              <div class="flex justify-end space-x-2">
                <button type="button" phx-click="hide_create_folder_modal"
                        class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg">
                  Cancel
                </button>
                <button type="submit"
                        class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg">
                  Create Folder
                </button>
              </div>
            </form>
          </div>
        </div>

        <!-- Rename File Modal -->
        <div :if={@show_rename_modal} class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50"
             phx-click="hide_rename_modal">
          <div class="bg-gray-800 rounded-lg p-6 w-96" phx-click-away="hide_rename_modal">
            <h3 class="text-white font-semibold text-lg mb-4">✏️ Rename File</h3>
            <form phx-submit="rename_file">
              <input type="hidden" name="file_id" value={@rename_file_id} />
              <input type="text" name="new_name" placeholder="New file name" required
                     value={if @rename_file_id, do: get_file_name(@files, @rename_file_id), else: ""}
                     class="w-full bg-gray-700 text-white px-4 py-2 rounded-lg mb-4 focus:ring-2 focus:ring-blue-500" />
              <div class="flex justify-end space-x-2">
                <button type="button" phx-click="hide_rename_modal"
                        class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg">
                  Cancel
                </button>
                <button type="submit"
                        class="bg-yellow-600 hover:bg-yellow-700 text-white px-4 py-2 rounded-lg">
                  Rename File
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for file type detection and formatting
  defp is_image?(file), do: String.starts_with?(file.content_type, "image/")
  defp is_video?(file), do: String.starts_with?(file.content_type, "video/")
  defp is_audio?(file), do: String.starts_with?(file.content_type, "audio/")
  defp is_document?(file) do
    file.content_type in [
      "application/pdf",
      "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "text/plain",
      "text/csv"
    ]
  end

  defp get_file_url(file) do
    # This should be implemented based on your file storage system
    # For now, returning a placeholder
    "/uploads/#{file.id}/#{file.original_filename}"
  end

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end
  defp format_file_size(_), do: "0 B"

  defp get_file_name(files, file_id) do
    case Enum.find(files, &(&1.id == file_id)) do
      nil -> ""
      file -> file.original_filename
    end
  end
end
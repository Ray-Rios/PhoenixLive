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
        page_title: "Files"
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
    <.navbar current_user={@current_user} />
    <div class="starry-background chat-container starry-background min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-indigo-900">
      <div class="stars-container">
        <div class="stars"></div>
        <div class="stars2"></div>
        <div class="stars3"></div>
      </div>
      
      <div class="container mx-auto px-4 py-8 relative z-10">
        <!-- File List View -->
        <div :if={@view == :list}>
          <!-- Header -->
          <div class="flex justify-between items-center mb-8">
            <h1 class="text-3xl font-bold text-white">My Files</h1>
            <.link navigate="/files/upload" class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg transition-colors">
              Upload Files
            </.link>
          </div>

          <!-- Stats -->
          <div class="grid grid-cols-1 md:grid-cols-5 gap-4 mb-8">
            <div class="bg-gray-800 rounded-lg p-4">
              <div class="text-2xl font-bold text-white"><%= @stats.total_files %></div>
              <div class="text-gray-400 text-sm">Total Files</div>
            </div>
            <div class="bg-gray-800 rounded-lg p-4">
              <div class="text-2xl font-bold text-blue-400"><%= @stats.images %></div>
              <div class="text-gray-400 text-sm">Images</div>
            </div>
            <div class="bg-gray-800 rounded-lg p-4">
              <div class="text-2xl font-bold text-green-400"><%= @stats.videos %></div>
              <div class="text-gray-400 text-sm">Videos</div>
            </div>
            <div class="bg-gray-800 rounded-lg p-4">
              <div class="text-2xl font-bold text-purple-400"><%= @stats.audio %></div>
              <div class="text-gray-400 text-sm">Audio</div>
            </div>
            <div class="bg-gray-800 rounded-lg p-4">
              <div class="text-2xl font-bold text-yellow-400"><%= @stats.documents %></div>
              <div class="text-gray-400 text-sm">Documents</div>
            </div>
          </div>

          <!-- Controls -->
          <div class="flex justify-between items-center mb-6">
            <div class="flex items-center space-x-4">
              <!-- Search -->
              <form phx-change="search" class="flex items-center">
                <input type="text" name="query" value={@search_query} placeholder="Search files..." 
                       class="bg-gray-700 text-white px-4 py-2 rounded-lg w-64" />
              </form>
              
              <!-- View Mode Toggle -->
              <div class="flex bg-gray-700 rounded-lg p-1">
                <button phx-click="toggle_view" phx-value-mode="grid"
                        class={["px-3 py-1 rounded text-sm transition-colors",
                               if(@view_mode == :grid, do: "bg-blue-600 text-white", else: "text-gray-300 hover:text-white")]}>
                  Grid
                </button>
                <button phx-click="toggle_view" phx-value-mode="list"
                        class={["px-3 py-1 rounded text-sm transition-colors",
                               if(@view_mode == :list, do: "bg-blue-600 text-white", else: "text-gray-300 hover:text-white")]}>
                  List
                </button>
              </div>
            </div>

            <!-- Selection Actions -->
            <div :if={MapSet.size(@selected_files) > 0} class="flex items-center space-x-2">
              <span class="text-gray-300 text-sm"><%= MapSet.size(@selected_files) %> selected</span>
              <button phx-click="delete_selected" 
                      class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm transition-colors"
                      onclick="return confirm('Are you sure you want to delete the selected files?')">
                Delete
              </button>
              <button phx-click="deselect_all" class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg text-sm transition-colors">
                Deselect All
              </button>
            </div>
            
            <div :if={MapSet.size(@selected_files) == 0 and @files != []} class="flex items-center space-x-2">
              <button phx-click="select_all" class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg text-sm transition-colors">
                Select All
              </button>
            </div>
          </div>

          <!-- Files Grid -->
          <div :if={@view_mode == :grid} class="file-grid">
            <%= for file <- @files do %>
              <div class={["file-item", if(MapSet.member?(@selected_files, file.id), do: "ring-2 ring-blue-500")]}
                   phx-click="select_file" phx-value-file_id={file.id}>
                
                <!-- File Icon/Preview -->
                <div class="file-icon text-center">
                  <%= cond do %>
                    <% PhoenixApp.Files.UserFile.is_image?(file) -> %>
                      <img src={PhoenixApp.UserFileUpload.url({file.file, file})} alt={file.filename} 
                           class="w-16 h-16 object-cover rounded mx-auto" />
                    <% PhoenixApp.Files.UserFile.is_video?(file) -> %>
                      <div class="text-green-400">🎥</div>
                    <% PhoenixApp.Files.UserFile.is_audio?(file) -> %>
                      <div class="text-purple-400">🎵</div>
                    <% PhoenixApp.Files.UserFile.is_document?(file) -> %>
                      <div class="text-yellow-400">📄</div>
                    <% true -> %>
                      <div class="text-gray-400">📁</div>
                  <% end %>
                </div>
                
                <div class="file-name text-white"><%= file.original_filename %></div>
                <div class="file-size text-gray-400"><%= PhoenixApp.Files.UserFile.format_file_size(file.file_size) %></div>
                
                <!-- File Actions -->
                <div class="flex justify-center space-x-2 mt-2">
                  <button phx-click="download_file" phx-value-file_id={file.id}
                          class="bg-blue-600 hover:bg-blue-700 text-white px-2 py-1 rounded text-xs transition-colors">
                    Download
                  </button>
                  <button :if={PhoenixApp.Files.UserFile.is_image?(file) or PhoenixApp.Files.UserFile.is_video?(file)}
                          phx-click="preview_file" phx-value-file_id={file.id}
                          class="bg-green-600 hover:bg-green-700 text-white px-2 py-1 rounded text-xs transition-colors">
                    Preview
                  </button>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Files List -->
          <div :if={@view_mode == :list} class="bg-gray-800 rounded-lg overflow-hidden">
            <table class="w-full">
              <thead class="bg-gray-700">
                <tr>
                  <th class="px-4 py-3 text-left text-white">Name</th>
                  <th class="px-4 py-3 text-left text-white">Type</th>
                  <th class="px-4 py-3 text-left text-white">Size</th>
                  <th class="px-4 py-3 text-left text-white">Modified</th>
                  <th class="px-4 py-3 text-left text-white">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for file <- @files do %>
                  <tr class={["border-b border-gray-700 hover:bg-gray-700 transition-colors",
                             if(MapSet.member?(@selected_files, file.id), do: "bg-blue-900")]}>
                    <td class="px-4 py-3">
                      <div class="flex items-center space-x-3">
                        <input type="checkbox" checked={MapSet.member?(@selected_files, file.id)}
                               phx-click="select_file" phx-value-file_id={file.id}
                               class="rounded bg-gray-600 border-gray-500" />
                        <span class="text-white"><%= file.original_filename %></span>
                      </div>
                    </td>
                    <td class="px-4 py-3 text-gray-300"><%= file.content_type %></td>
                    <td class="px-4 py-3 text-gray-300"><%= PhoenixApp.Files.UserFile.format_file_size(file.file_size) %></td>
                    <td class="px-4 py-3 text-gray-300"><%= Calendar.strftime(file.updated_at, "%m/%d/%Y") %></td>
                    <td class="px-4 py-3">
                      <div class="flex space-x-2">
                        <button phx-click="download_file" phx-value-file_id={file.id}
                                class="text-blue-400 hover:text-blue-300 text-sm">Download</button>
                        <button :if={PhoenixApp.Files.UserFile.is_image?(file) or PhoenixApp.Files.UserFile.is_video?(file)}
                                phx-click="preview_file" phx-value-file_id={file.id}
                                class="text-green-400 hover:text-green-300 text-sm">Preview</button>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <div :if={@files == []} class="text-center py-16">
            <div class="text-gray-400 text-xl">No files found</div>
            <p class="text-gray-500 mt-2">Upload your first file to get started</p>
            <.link navigate="/files/upload" class="inline-block mt-4 bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg transition-colors">
              Upload Files
            </.link>
          </div>
        </div>

        <!-- Upload View -->
        <div :if={@view == :upload} class="max-w-2xl mx-auto">
          <div class="flex items-center mb-8">
            <.link navigate="/files" class="text-blue-400 hover:text-blue-300 mr-4">← Back to Files</.link>
            <h1 class="text-3xl font-bold text-white">Upload Files</h1>
          </div>

          <div class="bg-gray-800 rounded-lg p-8">
            <div class="border-2 border-dashed border-gray-600 rounded-lg p-12 text-center">
              <input type="file" multiple phx-hook="FileUpload" id="file-upload"
                     class="hidden" />
              <label for="file-upload" class="cursor-pointer">
                <div class="text-6xl text-gray-400 mb-4">📁</div>
                <div class="text-xl text-white mb-2">Drop files here or click to browse</div>
                <div class="text-gray-400">Maximum file size: 10MB</div>
              </label>
            </div>

            <div class="mt-6 text-sm text-gray-400">
              <p><strong>Supported formats:</strong></p>
              <ul class="mt-2 space-y-1">
                <li>• Images: JPG, PNG, GIF, WebP</li>
                <li>• Documents: PDF, DOC, DOCX, TXT</li>
                <li>• Media: MP3, MP4, AVI, MOV</li>
                <li>• Archives: ZIP, RAR</li>
              </ul>
            </div>
          </div>
        </div>

        <!-- File Preview Modal -->
        <div :if={@preview_file} class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50"
             phx-click="close_preview">
          <div class="max-w-4xl max-h-full p-4" phx-click-away="close_preview">
            <div class="bg-gray-800 rounded-lg p-4">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-white font-semibold"><%= @preview_file.original_filename %></h3>
                <button phx-click="close_preview" class="text-gray-400 hover:text-white">✕</button>
              </div>
              
              <%= cond do %>
                <% PhoenixApp.Files.UserFile.is_image?(@preview_file) -> %>
                  <img src={PhoenixApp.UserFileUpload.url({@preview_file.file, @preview_file})} 
                       alt={@preview_file.filename} class="max-w-full max-h-96 mx-auto" />
                <% PhoenixApp.Files.UserFile.is_video?(@preview_file) -> %>
                  <video controls class="max-w-full max-h-96 mx-auto">
                    <source src={PhoenixApp.UserFileUpload.url({@preview_file.file, @preview_file})} 
                            type={@preview_file.content_type} />
                  </video>
                <% true -> %>
                  <div class="text-center text-gray-400 py-8">Preview not available for this file type</div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
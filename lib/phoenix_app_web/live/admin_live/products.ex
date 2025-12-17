defmodule PhoenixAppWeb.AdminLive.Products do
  use PhoenixAppWeb, :live_view
  alias PhoenixApp.Commerce
  alias PhoenixApp.Commerce.Product
  alias PhoenixAppWeb.Components.AdminSidebar

  on_mount {PhoenixAppWeb.UserAuth, :require_admin_user}

  @product_types [
    {"Physical Product", "physical"},
    {"Digital Download", "digital"},
    {"Service", "service"},
    {"Subscription", "subscription"}
  ]

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Admin - Products",
       products: Commerce.list_products(),
       categories: Commerce.list_categories(),
       product_types: @product_types,
       show_form: false,
       editing_product: nil,
       form: to_form(Product.changeset(%Product{}, %{})),
       syncing_stripe: false
     )}
  end

  def handle_event("new_product", _params, socket) do
    {:noreply, 
     assign(socket, 
       show_form: true, 
       editing_product: nil, 
       form: to_form(Product.changeset(%Product{}, %{}))
     )}
  end

  def handle_event("edit_product", %{"id" => id}, socket) do
    product = Commerce.get_product!(id)
    {:noreply, 
     assign(socket, 
       show_form: true, 
       editing_product: product, 
       form: to_form(Product.changeset(product, %{}))
     )}
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply, 
     assign(socket, 
       show_form: false, 
       editing_product: nil, 
       form: to_form(Product.changeset(%Product{}, %{}))
     )}
  end

  def handle_event("validate", %{"product" => params}, socket) do
    changeset = 
      (socket.assigns.editing_product || %Product{}) 
      |> Product.changeset(params) 
      |> Map.put(:action, :validate)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"product" => params}, socket) do
    case socket.assigns.editing_product do
      nil ->
        # Create new product
        case Commerce.create_product(params) do
          {:ok, product} ->
            # Sync to Stripe if configured
            sync_product_to_stripe(product)
            
            {:noreply,
             socket
             |> assign(products: Commerce.list_products(), show_form: false)
             |> put_flash(:info, "Product '#{product.name}' created successfully!")}
          {:error, changeset} ->
            {:noreply, 
             socket 
             |> assign(form: to_form(changeset)) 
             |> put_flash(:error, "Failed to create product")}
        end
      
      product ->
        # Update existing product
        case Commerce.update_product(product, params) do
          {:ok, updated_product} ->
            # Sync to Stripe if configured
            sync_product_to_stripe(updated_product)
            
            {:noreply,
             socket
             |> assign(products: Commerce.list_products(), show_form: false)
             |> put_flash(:info, "Product '#{updated_product.name}' updated!")}
          {:error, changeset} ->
            {:noreply, 
             socket 
             |> assign(form: to_form(changeset)) 
             |> put_flash(:error, "Failed to update product")}
        end
    end
  end

  def handle_event("delete_product", %{"id" => id}, socket) do
    product = Commerce.get_product!(id)
    
    case Commerce.delete_product(product) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(products: Commerce.list_products())
         |> put_flash(:info, "Product deleted")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete product")}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    product = Commerce.get_product!(id)
    
    case Commerce.update_product(product, %{is_active: !product.is_active}) do
      {:ok, _} ->
        {:noreply, assign(socket, products: Commerce.list_products())}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update product status")}
    end
  end

  def handle_event("sync_to_stripe", %{"id" => id}, socket) do
    product = Commerce.get_product!(id)
    
    case sync_product_to_stripe(product) do
      {:ok, stripe_price_id} ->
        if stripe_price_id do
          Commerce.update_product(product, %{stripe_price_id: stripe_price_id})
        end
        {:noreply,
         socket
         |> assign(products: Commerce.list_products())
         |> put_flash(:info, "Product synced to Stripe!")}
      # {:error, reason} ->
      #   {:noreply, put_flash(socket, :error, "Stripe sync failed: #{reason}")}
    end
  end

  @spec sync_product_to_stripe(any()) :: {:ok, String.t() | nil} | {:error, String.t()}
  defp sync_product_to_stripe(_product) do
    # TODO: Implement Stripe product/price sync
    # This would create a Stripe Product and Price, then return the price_id
    {:ok, nil}
  end

  def render(assigns) do
    ~H"""
    <AdminSidebar.admin_layout current_path="/admin/products">
      <div class="max-w-6xl mx-auto">
          <div class="auth-glass-panel p-8 rounded-xl">
            <!-- Header -->
            <div class="flex justify-between items-center mb-8">
              <div>
                <h1 class="text-3xl font-bold text-white">Products</h1>
                <p class="text-gray-400 mt-1">Manage products, services, and subscriptions</p>
              </div>
              <button phx-click="new_product" class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg transition-colors">
                ➕ New Product
              </button>
            </div>

            <%= if @show_form do %>
              <!-- Product Form -->
              <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-6 mb-8">
                <div class="bg-gray-800/50 p-6 rounded-lg border border-gray-700">
                  <h3 class="text-lg font-semibold text-white mb-4">
                    <%= if @editing_product, do: "Edit Product", else: "New Product" %>
                  </h3>
                  
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-1">Product Name *</label>
                      <.input field={@form[:name]} type="text" placeholder="Product name" class="w-full bg-gray-700 border-gray-600 text-white rounded-lg" />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-1">SKU *</label>
                      <.input field={@form[:sku]} type="text" placeholder="PROD-001" class="w-full bg-gray-700 border-gray-600 text-white rounded-lg" />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-1">Price *</label>
                      <.input field={@form[:price]} type="number" step="0.01" placeholder="9.99" class="w-full bg-gray-700 border-gray-600 text-white rounded-lg" />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-1">Stock Quantity</label>
                      <.input field={@form[:stock_quantity]} type="number" placeholder="100" class="w-full bg-gray-700 border-gray-600 text-white rounded-lg" />
                    </div>
                    
                    <div class="md:col-span-2">
                      <label class="block text-sm font-medium text-gray-300 mb-1">Description</label>
                      <.input field={@form[:description]} type="textarea" rows="3" placeholder="Product description..." class="w-full bg-gray-700 border-gray-600 text-white rounded-lg" />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-1">Weight (kg)</label>
                      <.input field={@form[:weight]} type="number" step="0.01" placeholder="0.5" class="w-full bg-gray-700 border-gray-600 text-white rounded-lg" />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-1">Dimensions</label>
                      <.input field={@form[:dimensions]} type="text" placeholder="10x10x5 cm" class="w-full bg-gray-700 border-gray-600 text-white rounded-lg" />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-1">Stripe Price ID</label>
                      <.input field={@form[:stripe_price_id]} type="text" placeholder="price_xxx" class="w-full bg-gray-700 border-gray-600 text-white rounded-lg" />
                    </div>
                  </div>
                  
                  <div class="flex justify-end gap-3 mt-6">
                    <button type="button" phx-click="cancel_form" class="px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg">
                      Cancel
                    </button>
                    <button type="submit" class="px-6 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg">
                      <%= if @editing_product, do: "Update Product", else: "Create Product" %>
                    </button>
                  </div>
                </div>
              </.form>
            <% end %>

            <!-- Products Table -->
            <div class="bg-gray-800/50 rounded-lg border border-gray-700 overflow-hidden">
              <table class="w-full">
                <thead class="bg-black/30">
                  <tr>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">Product</th>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">SKU</th>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">Price</th>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">Stock</th>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">Status</th>
                    <th class="text-left text-gray-300 px-4 py-3 text-sm font-medium">Stripe</th>
                    <th class="text-right text-gray-300 px-4 py-3 text-sm font-medium">Actions</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-700">
                  <%= if @products == [] do %>
                    <tr>
                      <td colspan="7" class="px-4 py-8 text-center text-gray-500">
                        No products yet. Click "New Product" to create one.
                      </td>
                    </tr>
                  <% else %>
                    <%= for product <- @products do %>
                      <tr class="hover:bg-white/5">
                        <td class="px-4 py-3">
                          <div class="flex items-center gap-3">
                            <div class="w-10 h-10 bg-gray-700 rounded-lg flex items-center justify-center text-xl">
                              🛍️
                            </div>
                            <div>
                              <p class="text-white font-medium"><%= product.name %></p>
                              <p class="text-gray-500 text-xs truncate max-w-[200px]"><%= product.description %></p>
                            </div>
                          </div>
                        </td>
                        <td class="px-4 py-3 text-gray-400 text-sm font-mono">
                          <%= product.sku %>
                        </td>
                        <td class="px-4 py-3 text-green-400 font-medium">
                          $<%= product.price %>
                        </td>
                        <td class="px-4 py-3">
                          <span class={[
                            "text-sm",
                            if(product.stock_quantity && product.stock_quantity > 10, do: "text-green-400", else: "text-yellow-400")
                          ]}>
                            <%= product.stock_quantity || "∞" %>
                          </span>
                        </td>
                        <td class="px-4 py-3">
                          <button
                            phx-click="toggle_active"
                            phx-value-id={product.id}
                            class={[
                              "px-2 py-1 rounded text-xs",
                              if(product.is_active, do: "bg-green-600/30 text-green-300", else: "bg-red-600/30 text-red-300")
                            ]}
                          >
                            <%= if product.is_active, do: "Active", else: "Inactive" %>
                          </button>
                        </td>
                        <td class="px-4 py-3">
                          <%= if product.stripe_price_id do %>
                            <span class="text-green-400 text-xs">✓ Synced</span>
                          <% else %>
                            <button
                              phx-click="sync_to_stripe"
                              phx-value-id={product.id}
                              class="text-blue-400 hover:text-blue-300 text-xs"
                            >
                              Sync
                            </button>
                          <% end %>
                        </td>
                        <td class="px-4 py-3 text-right">
                          <button
                            phx-click="edit_product"
                            phx-value-id={product.id}
                            class="text-blue-400 hover:text-blue-300 text-sm mr-3"
                          >
                            Edit
                          </button>
                          <button
                            phx-click="delete_product"
                            phx-value-id={product.id}
                            data-confirm="Are you sure you want to delete this product?"
                            class="text-red-400 hover:text-red-300 text-sm"
                          >
                            Delete
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
      </div>
    </AdminSidebar.admin_layout>
    """
  end
end
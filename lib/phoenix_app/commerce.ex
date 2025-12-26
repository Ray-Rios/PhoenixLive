defmodule PhoenixApp.Commerce do
  @moduledoc """
  The Commerce context for e-commerce functionality.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.Commerce.{Product, Order, OrderItem, Category, Cart, CartItem, Subscription, DownloadToken}

  # Products
  def list_products do
    Repo.all(from p in Product, where: p.is_active == true, order_by: [asc: p.sort_order, desc: p.inserted_at])
  end
  
  def list_all_products do
    Repo.all(from p in Product, order_by: [asc: p.sort_order, desc: p.inserted_at])
  end
  
  def list_products_by_type(type) do
    from(p in Product, where: p.is_active == true and p.product_type == ^type, order_by: [asc: p.sort_order])
    |> Repo.all()
  end
  
  def list_subscription_products do
    from(p in Product, 
      where: p.is_active == true and p.billing_interval != "one_time",
      order_by: [asc: p.sort_order, asc: p.price]
    )
    |> Repo.all()
  end
  
  def list_featured_products do
    from(p in Product, where: p.is_active == true and p.featured == true, order_by: [asc: p.sort_order])
    |> Repo.all()
  end

  def get_product!(id), do: Repo.get!(Product, id)

  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  # Categories
  def list_categories do
    Repo.all(Category)
  end

  def get_category!(id), do: Repo.get!(Category, id)

  def create_category(attrs \\ %{}) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  # Orders
  def list_orders do
    Repo.all(Order) |> Repo.preload([:user, :order_items])
  end

  def get_order!(id) do
    Repo.get!(Order, id) |> Repo.preload([:user, :order_items])
  end

  def create_order(user, attrs \\ %{}) do
    %Order{}
    |> Order.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  def update_order(%Order{} = order, attrs) do
    order
    |> Order.changeset(attrs)
    |> Repo.update()
  end

  # Cart functionality
  def get_or_create_cart(user) do
    case Repo.get_by(Cart, user_id: user.id) do
      nil -> 
        %Cart{}
        |> Cart.changeset(%{user_id: user.id})
        |> Repo.insert!()
      cart -> cart
    end
    |> Repo.preload([:cart_items, :user])
  end

  def add_to_cart(cart, product, quantity \\ 1) do
    case Repo.get_by(CartItem, cart_id: cart.id, product_id: product.id) do
      nil ->
        %CartItem{}
        |> CartItem.changeset(%{
          cart_id: cart.id,
          product_id: product.id,
          quantity: quantity
        })
        |> Repo.insert()
      
      cart_item ->
        cart_item
        |> CartItem.changeset(%{quantity: cart_item.quantity + quantity})
        |> Repo.update()
    end
  end

  def remove_from_cart(cart_item) do
    Repo.delete(cart_item)
  end

  def clear_cart(cart) do
    from(ci in CartItem, where: ci.cart_id == ^cart.id)
    |> Repo.delete_all()
  end

  def calculate_cart_total(cart) do
    cart = Repo.preload(cart, [cart_items: :product])
    
    Enum.reduce(cart.cart_items, Decimal.new(0), fn item, acc ->
      item_total = Decimal.mult(item.product.price, item.quantity)
      Decimal.add(acc, item_total)
    end)
  end

  def get_cart_item!(id), do: Repo.get!(CartItem, id)

  def update_cart_item(%CartItem{} = cart_item, attrs) do
    cart_item
    |> CartItem.changeset(attrs)
    |> Repo.update()
  end

  def create_order_item(order, attrs) do
    %OrderItem{}
    |> OrderItem.changeset(Map.put(attrs, :order_id, order.id))
    |> Repo.insert()
  end

  def get_order_by_stripe_payment_intent(payment_intent_id) do
    case Repo.get_by(Order, stripe_payment_intent_id: payment_intent_id) do
      nil -> {:error, :not_found}
      order -> {:ok, order}
    end
  end

  def list_products_by_category(category_id) do
    from(p in Product, where: p.category_id == ^category_id and p.is_active == true)
    |> Repo.all()
  end

  def get_category_by_slug!(slug) do
    Repo.get_by!(Category, slug: slug)
  end

  # Admin functions
  def count_orders do
    Repo.aggregate(Order, :count)
  end

  def count_products do
    Repo.aggregate(Product, :count)
  end

  def list_recent_orders(limit \\ 10) do
    from(o in Order, 
      order_by: [desc: o.inserted_at], 
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  def get_revenue_today do
    today = Date.utc_today()
    
    from(o in Order,
      where: fragment("DATE(?)", o.inserted_at) == ^today and o.status != "cancelled",
      select: sum(o.total_amount)
    )
    |> Repo.one() || Decimal.new(0)
  end

  def get_revenue_month do
    start_of_month = Date.utc_today() |> Date.beginning_of_month()
    
    from(o in Order,
      where: fragment("DATE(?)", o.inserted_at) >= ^start_of_month and o.status != "cancelled",
      select: sum(o.total_amount)
    )
    |> Repo.one() || Decimal.new(0)
  end

  def list_user_orders(user) do
    from(o in Order,
      where: o.user_id == ^user.id,
      order_by: [desc: o.inserted_at],
      preload: [:order_items]
    )
    |> Repo.all()
  end

  # =============================================
  # Subscriptions
  # =============================================

  def list_subscriptions do
    Repo.all(from s in Subscription, preload: [:user, :product], order_by: [desc: s.inserted_at])
  end

  def get_subscription!(id) do
    Repo.get!(Subscription, id) |> Repo.preload([:user, :product])
  end

  def get_user_subscriptions(user) do
    from(s in Subscription,
      where: s.user_id == ^user.id,
      order_by: [desc: s.inserted_at],
      preload: [:product]
    )
    |> Repo.all()
  end

  def get_user_active_subscriptions(user) do
    now = DateTime.utc_now()
    
    from(s in Subscription,
      where: s.user_id == ^user.id and s.status in ["active", "trial"],
      where: is_nil(s.expires_at) or s.expires_at > ^now,
      preload: [:product]
    )
    |> Repo.all()
  end

  def get_active_subscription(user, product_id) do
    now = DateTime.utc_now()
    
    from(s in Subscription,
      where: s.user_id == ^user.id and s.product_id == ^product_id,
      where: s.status in ["active", "trial"],
      where: is_nil(s.expires_at) or s.expires_at > ^now,
      limit: 1
    )
    |> Repo.one()
  end

  def create_subscription(attrs) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  def update_subscription(%Subscription{} = subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  def cancel_subscription(%Subscription{} = subscription, opts \\ []) do
    at_period_end = Keyword.get(opts, :at_period_end, true)
    
    attrs = if at_period_end do
      %{cancel_at_period_end: true}
    else
      %{status: "cancelled", cancelled_at: DateTime.utc_now()}
    end
    
    update_subscription(subscription, attrs)
  end

  @doc """
  Activates a subscription for a user after successful payment.
  Also applies the subscription benefits (storage, role, features).
  """
  def activate_subscription(user, product, opts \\ []) do
    now = DateTime.utc_now()
    
    # Calculate expiration based on billing interval
    expires_at = case product.billing_interval do
      "monthly" -> DateTime.add(now, 30, :day)
      "yearly" -> DateTime.add(now, 365, :day)
      "lifetime" -> nil
      _ -> nil  # one_time doesn't expire but also isn't a subscription
    end
    
    # Handle trial period
    {status, trial_ends_at} = if product.trial_days > 0 and Keyword.get(opts, :apply_trial, true) do
      {"trial", DateTime.add(now, product.trial_days, :day)}
    else
      {"active", nil}
    end
    
    subscription_attrs = %{
      user_id: user.id,
      product_id: product.id,
      status: status,
      starts_at: now,
      expires_at: expires_at,
      trial_ends_at: trial_ends_at,
      storage_bytes_granted: product.grants_storage_bytes || 0,
      role_granted: product.grants_role,
      features_granted: product.grants_features || [],
      current_period_start: now,
      current_period_end: expires_at,
      stripe_subscription_id: opts[:stripe_subscription_id],
      stripe_customer_id: opts[:stripe_customer_id]
    }
    
    with {:ok, subscription} <- create_subscription(subscription_attrs),
         {:ok, _user} <- apply_subscription_benefits(user, subscription) do
      {:ok, subscription}
    end
  end

  @doc """
  Applies the benefits from a subscription to the user's account.
  """
  def apply_subscription_benefits(user, subscription) do
    updates = %{}
    
    # Add granted storage to quota
    updates = if subscription.storage_bytes_granted > 0 do
      new_quota = (user.storage_quota_bytes || 1_073_741_824) + subscription.storage_bytes_granted
      Map.put(updates, :storage_quota_bytes, new_quota)
    else
      updates
    end
    
    # Apply role upgrade if granted
    updates = if subscription.role_granted do
      Map.put(updates, :role, subscription.role_granted)
    else
      updates
    end
    
    # Merge subscription features with existing features
    updates = if subscription.features_granted != [] do
      current_features = user.subscription_features || []
      new_features = Enum.uniq(current_features ++ subscription.features_granted)
      Map.put(updates, :subscription_features, new_features)
    else
      updates
    end
    
    # Determine subscription tier based on active subscriptions
    updates = Map.put(updates, :subscription_tier, determine_tier(user))
    
    if map_size(updates) > 0 do
      PhoenixApp.Accounts.update_user_subscription_fields(user, updates)
    else
      {:ok, user}
    end
  end

  defp determine_tier(user) do
    active_subs = get_user_active_subscriptions(user)
    
    cond do
      Enum.any?(active_subs, fn s -> s.product && s.product.grants_role == "enterprise" end) -> "enterprise"
      Enum.any?(active_subs, fn s -> s.product && s.product.grants_role in ["pro", "editor"] end) -> "pro"
      Enum.any?(active_subs, fn s -> s.product && s.product.grants_role == "basic" end) -> "basic"
      active_subs != [] -> "basic"
      true -> "free"
    end
  end

  @doc """
  Checks if a user has access to a specific feature.
  """
  def user_has_feature?(user, feature) do
    feature in (user.subscription_features || [])
  end

  @doc """
  Calculates the user's total storage quota including subscription bonuses.
  """
  def get_user_storage_quota(user) do
    user.storage_quota_bytes || 1_073_741_824  # 1GB default
  end

  @doc """
  Checks if a user can upload a file of the given size.
  """
  def can_upload?(user, file_size) do
    quota = get_user_storage_quota(user)
    used = user.storage_used_bytes || 0
    used + file_size <= quota
  end

  # =============================================
  # Download Tokens (Digital Product Delivery)
  # =============================================

  @doc """
  Creates a download token for a user to access a digital product.
  """
  def create_download_token(user, product, opts \\ []) do
    max_downloads = opts[:max_downloads] || product.download_limit || 5
    expires_in_days = opts[:expires_in_days] || 30
    
    attrs = %{
      user_id: user.id,
      product_id: product.id,
      order_id: opts[:order_id],
      max_downloads: max_downloads,
      expires_at: DateTime.add(DateTime.utc_now(), expires_in_days, :day)
    }
    
    DownloadToken.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a download token by its token string.
  """
  def get_download_token(token_string) do
    Repo.get_by(DownloadToken, token: token_string)
    |> Repo.preload([:user, :product])
  end

  @doc """
  Gets all download tokens for a user.
  """
  def get_user_download_tokens(user) do
    from(dt in DownloadToken,
      where: dt.user_id == ^user.id,
      order_by: [desc: dt.inserted_at],
      preload: [:product]
    )
    |> Repo.all()
  end

  @doc """
  Validates and records a download attempt.
  Returns {:ok, download_url} or {:error, reason}.
  """
  def attempt_download(token_string, ip_address \\ nil) do
    case get_download_token(token_string) do
      nil ->
        {:error, :invalid_token}
      
      token ->
        cond do
          DownloadToken.expired?(token) ->
            {:error, :token_expired}
          
          DownloadToken.download_limit_reached?(token) ->
            {:error, :download_limit_reached}
          
          true ->
            # Record the download
            token
            |> DownloadToken.record_download_changeset(ip_address)
            |> Repo.update()
            |> case do
              {:ok, _updated_token} ->
                {:ok, token.product.download_url}
              {:error, changeset} ->
                {:error, changeset}
            end
        end
    end
  end

  @doc """
  Gets download tokens that are about to expire (within X days).
  """
  def get_expiring_tokens(days \\ 7) do
    deadline = DateTime.add(DateTime.utc_now(), days, :day)
    
    from(dt in DownloadToken,
      where: not is_nil(dt.expires_at) and dt.expires_at <= ^deadline,
      where: dt.download_count == 0,  # Never downloaded
      preload: [:user, :product]
    )
    |> Repo.all()
  end
end
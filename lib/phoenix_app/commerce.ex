defmodule PhoenixApp.Commerce do
  @moduledoc """
  The Commerce context for e-commerce functionality.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.Commerce.{Product, Order, OrderItem, Category, Cart, CartItem}

  # Products
  def list_products do
    Repo.all(Product)
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
end
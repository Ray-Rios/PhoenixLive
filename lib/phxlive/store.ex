defmodule Phxlive.Store do
  @moduledoc """
  The store (PHXLIVE.md §8): Gem packs now, subscription plans and items
  later. One Buy button per product, no cart.

  Buying: `start_checkout/3` creates an order and a hosted checkout and
  returns where to send the buyer. The order is paid only when the provider's
  event says so (`apply_event/1`, called by `Phxlive.Payments`), never because
  the buyer came back to the success page. Fulfilling a Gem pack credits the
  wallet in the same transaction that marks the order fulfilled.

  Sales are final: there's no refund path. A chargeback the hub loses takes
  the Gems back (`Phxlive.Wallet.clawback/3`).
  """

  import Ecto.Query
  alias Phxlive.{Repo, Wallet}
  alias Phxlive.Accounts.User
  alias Phxlive.Payments.Event
  alias Phxlive.Store.{Order, Product}

  @gems_per_dollar 100

  @doc "The house rate: 100 Gems = US$1."
  def gems_per_dollar, do: @gems_per_dollar

  def topic(%Order{id: id}), do: "store:order:#{id}"
  def topic(id) when is_binary(id), do: "store:order:#{id}"

  # ---------------------------------------------------------------------------
  # Products
  # ---------------------------------------------------------------------------

  @doc "Active Gem packs, in display order."
  def gem_packs do
    Repo.all(from p in Product, where: p.kind == "gem_pack" and p.active, order_by: [asc: p.sort_order, asc: p.price_cents])
  end

  def get_product(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(Product, uuid)
      :error -> nil
    end
  end

  def list_products, do: Repo.all(from p in Product, order_by: [asc: p.kind, asc: p.sort_order])

  def create_product(attrs), do: %Product{} |> Product.changeset(attrs) |> Repo.insert()
  def update_product(%Product{} = p, attrs), do: p |> Product.changeset(attrs) |> Repo.update()

  @doc "Gems a pack gives if bought at `now`: its Gems, plus its bonus while a promotion runs."
  def gems_for(%Product{gems: gems} = p, now \\ DateTime.utc_now()) do
    (gems || 0) + if(promo_active?(p, now), do: p.bonus_gems || 0, else: 0)
  end

  def promo_active?(%Product{bonus_gems: bonus} = p, now \\ DateTime.utc_now()) do
    is_integer(bonus) and bonus > 0 and not is_nil(p.promo_starts_at) and not is_nil(p.promo_ends_at) and
      DateTime.compare(now, p.promo_starts_at) != :lt and DateTime.compare(now, p.promo_ends_at) == :lt
  end

  @doc "US$ for display: 500 -> \"$5.00\"."
  def format_price(cents, "usd"), do: "$" <> :erlang.float_to_binary(cents / 100, decimals: 2)
  def format_price(cents, currency), do: "#{:erlang.float_to_binary(cents / 100, decimals: 2)} #{String.upcase(currency)}"

  # ---------------------------------------------------------------------------
  # Who can buy
  # ---------------------------------------------------------------------------

  @doc "Is a payment provider configured? (False in production until Stripe is set up.)"
  def checkout_available?, do: match?({:ok, _}, Phxlive.Payments.provider(Phxlive.Payments.default_provider()))

  @doc """
  `:ok`, or why this user can't buy: `:not_signed_in`, `:not_eligible`
  (Guest or Banned, or the account isn't active) or `:email_unverified`.
  Members and up may buy, the same rule as storage tiers.
  """
  def can_buy(nil), do: {:error, :not_signed_in}

  def can_buy(%User{} = user) do
    cond do
      not Phxlive.Drive.Policy.can_purchase_storage?(user) -> {:error, :not_eligible}
      not User.email_verified?(user) -> {:error, :email_unverified}
      true -> :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Buying
  # ---------------------------------------------------------------------------

  @doc """
  Creates an order and a hosted checkout. `opts`: `:accept_terms` must be
  true (the buyer ticked "all sales are final"); `:provider` (default
  `Phxlive.Payments.default_provider/0`); `:success_url` and `:cancel_url`
  (built from the order id when not given).

  Returns `{:ok, order, redirect_url}`.
  """
  def start_checkout(user, %Product{} = product, opts \\ []) do
    provider_name = Keyword.get(opts, :provider, Phxlive.Payments.default_provider())

    with :ok <- can_buy(user),
         :ok <- check_terms(opts),
         :ok <- check_product(product),
         {:ok, provider} <- Phxlive.Payments.provider(provider_name) do
      now = DateTime.utc_now()

      order =
        Repo.insert!(%Order{
          user_id: user.id,
          product_id: product.id,
          status: "awaiting_payment",
          provider: provider.name(),
          product_name: product.name,
          amount_cents: product.price_cents,
          currency: product.currency,
          gems: gems_for(product, now),
          terms_accepted_at: now
        })

      urls = [
        success_url: Keyword.get(opts, :success_url, "/store/orders/#{order.id}"),
        cancel_url: Keyword.get(opts, :cancel_url, "/store/orders/#{order.id}")
      ]

      case provider.create_checkout(order, urls) do
        {:ok, %{redirect_url: url, provider_ref: ref}} ->
          order = order |> Ecto.Changeset.change(provider_ref: ref) |> Repo.update!()
          {:ok, order, url}

        {:error, reason} ->
          order |> Ecto.Changeset.change(status: "failed", failure_reason: "checkout: #{inspect(reason)}") |> Repo.update!()
          {:error, {:checkout_failed, reason}}
      end
    end
  end

  defp check_terms(opts), do: if(Keyword.get(opts, :accept_terms) == true, do: :ok, else: {:error, :terms_not_accepted})

  defp check_product(%Product{active: true, kind: "gem_pack"}), do: :ok
  defp check_product(%Product{active: false}), do: {:error, :not_for_sale}
  defp check_product(_), do: {:error, :not_supported_yet}

  @doc "An order, if it belongs to this user."
  def get_user_order(%User{id: user_id}, id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Order{user_id: ^user_id} = order <- Repo.get(Order, uuid) do
      order
    else
      _ -> nil
    end
  end

  def get_order_by_ref(provider, ref), do: Repo.get_by(Order, provider: provider, provider_ref: ref)

  def list_user_orders(%User{id: user_id}, limit \\ 50) do
    Repo.all(from o in Order, where: o.user_id == ^user_id, order_by: [desc: o.inserted_at], limit: ^limit)
  end

  def list_orders(limit \\ 100) do
    Repo.all(from o in Order, order_by: [desc: o.inserted_at], limit: ^limit, preload: [:user])
  end

  # ---------------------------------------------------------------------------
  # Provider events (called by Phxlive.Payments)
  # ---------------------------------------------------------------------------

  @doc """
  Applies a provider event to its order. Idempotent: an event that finds its
  order already past the step it describes does nothing. Returns `:ok` or
  `{:error, reason}` (the provider will retry).
  """
  def apply_event(%Event{provider: provider, provider_ref: ref} = event) do
    Repo.transaction(fn ->
      case Repo.one(from o in Order, where: o.provider == ^provider and o.provider_ref == ^ref, lock: "FOR UPDATE") do
        nil -> Repo.rollback(:unknown_order)
        order -> transition(order, event)
      end
    end)
    |> case do
      {:ok, {:changed, order}} ->
        Phoenix.PubSub.broadcast(Phxlive.PubSub, topic(order), {:order_updated, order})
        :ok

      {:ok, :unchanged} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Money taken: check it's what the order says, then pay and fulfil. Also
  # from cancelled/failed: the buyer may have left our page and still paid in
  # the provider's, and money taken must always be honoured.
  defp transition(%Order{status: status} = order, %Event{type: :checkout_completed} = e)
       when status in ["awaiting_payment", "cancelled", "failed"] do
    if e.amount_cents == order.amount_cents and String.downcase(e.currency || "") == order.currency do
      now = DateTime.utc_now()
      order = order |> Ecto.Changeset.change(status: "paid", paid_at: now) |> Repo.update!()
      {:changed, fulfil!(order)}
    else
      Repo.rollback({:amount_mismatch, %{expected: {order.amount_cents, order.currency}, got: {e.amount_cents, e.currency}}})
    end
  end

  defp transition(%Order{status: "awaiting_payment"} = order, %Event{type: :checkout_failed}) do
    {:changed, order |> Ecto.Changeset.change(status: "failed", failure_reason: "checkout not completed") |> Repo.update!()}
  end

  defp transition(%Order{status: "fulfilled"} = order, %Event{type: :dispute_opened}) do
    {:changed, order |> Ecto.Changeset.change(status: "disputed") |> Repo.update!()}
  end

  defp transition(%Order{status: "disputed"} = order, %Event{type: :dispute_won}) do
    {:changed, order |> Ecto.Changeset.change(status: "fulfilled") |> Repo.update!()}
  end

  # The bank took the money back; the Gems it paid for go too.
  defp transition(%Order{status: status} = order, %Event{type: :dispute_lost}) when status in ["disputed", "fulfilled"] do
    if order.gems > 0 do
      case Wallet.clawback(order.user_id, order.gems, order) do
        {:ok, _} -> :ok
        {:ok, _, :duplicate} -> :ok
        {:error, reason} -> Repo.rollback({:clawback_failed, reason})
      end
    end

    {:changed, order |> Ecto.Changeset.change(status: "charged_back") |> Repo.update!()}
  end

  # Anything else is a re-delivery or an event for a later state: nothing to do.
  defp transition(_order, _event), do: :unchanged

  defp fulfil!(%Order{gems: gems} = order) when gems > 0 do
    case Wallet.credit_purchase(order.user_id, gems, order, memo: order.product_name) do
      {:ok, _} -> :ok
      {:ok, _, :duplicate} -> :ok
      {:error, reason} -> Repo.rollback({:fulfil_failed, reason})
    end

    order |> Ecto.Changeset.change(status: "fulfilled", fulfilled_at: DateTime.utc_now()) |> Repo.update!()
  end

  defp fulfil!(order), do: order |> Ecto.Changeset.change(status: "fulfilled", fulfilled_at: DateTime.utc_now()) |> Repo.update!()

  @doc "The buyer abandoned checkout on our side (back button on the fake page, or a cancel URL)."
  def cancel_unpaid(%Order{status: "awaiting_payment"} = order) do
    order = order |> Ecto.Changeset.change(status: "cancelled") |> Repo.update!()
    Phoenix.PubSub.broadcast(Phxlive.PubSub, topic(order), {:order_updated, order})
    {:ok, order}
  end

  def cancel_unpaid(order), do: {:ok, order}
end

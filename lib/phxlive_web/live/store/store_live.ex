defmodule PhxliveWeb.StoreLive do
  @moduledoc """
  /store - Gem packs, one Buy button each (PHXLIVE.md §8). Anyone can look;
  buying needs a verified member account and the "all sales are final" box
  ticked. Buy creates the order and sends the buyer to the provider's hosted
  checkout.
  """
  use PhxliveWeb, :live_view

  alias Phxlive.{Store, Wallet}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]

    {:ok,
     assign(socket,
       page_title: "Store",
       packs: Store.gem_packs(),
       balance: user && Wallet.balance(user),
       can_buy: Store.can_buy(user),
       open?: Store.checkout_available?(),
       accepted?: false
     )}
  end

  @impl true
  def handle_event("accept_terms", params, socket) do
    {:noreply, assign(socket, accepted?: params["accept"] == "true")}
  end

  def handle_event("buy", %{"product_id" => id}, socket) do
    user = socket.assigns[:current_user]

    with %Store.Product{} = product <- Store.get_product(id),
         {:ok, _order, url} <- Store.start_checkout(user, product, accept_terms: socket.assigns.accepted?) do
      {:noreply, go(socket, url)}
    else
      nil -> {:noreply, put_flash(socket, :error, "That pack isn't for sale.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, message(reason))}
    end
  end

  # Sent by the desktop taskbar in the app layout; nothing to do here.
  def handle_event(event, _params, socket) when event in ["toggle_calendar", "toggle_start_menu", "open_app"],
    do: {:noreply, socket}

  defp go(socket, "/" <> _ = path), do: push_navigate(socket, to: path)
  defp go(socket, url), do: redirect(socket, external: url)

  defp message(:not_signed_in), do: "Sign in to buy Gems."
  defp message(:not_eligible), do: "Your account can't make purchases."
  defp message(:email_unverified), do: "Verify your email address before buying."
  defp message(:terms_not_accepted), do: "Please confirm that all sales are final."
  defp message(:not_for_sale), do: "That pack isn't for sale."
  defp message(_), do: "Checkout couldn't be started. Please try again."

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed top-[30px] inset-x-0 bottom-0 z-40 overflow-y-auto bg-black">
      <div class="max-w-5xl mx-auto px-6 py-16">
        <div class="flex flex-wrap items-end justify-between gap-4 mb-10">
          <div>
            <h1 class="text-3xl font-bold text-white mb-2">Store</h1>
            <p class="text-gray-400">Gems work in every game on the hub. 100 Gems = $1.</p>
          </div>
          <div :if={@balance} class="glass-dark rounded-lg px-5 py-3 border border-gray-700 text-right">
            <div class="text-xs uppercase tracking-wide text-gray-500">Your Gems</div>
            <div class="text-2xl font-semibold text-white">💎 {format_number(@balance)}</div>
            <.link navigate={~p"/store/orders"} class="text-xs text-blue-400 hover:underline">Purchase history</.link>
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <div
            :for={pack <- @packs}
            class="glass-dark rounded-lg p-6 border border-gray-700 flex flex-col"
          >
            <div class="flex items-start justify-between">
              <div class="text-4xl mb-3">💎</div>
              <span :if={pack.badge} class="text-xs px-2 py-1 rounded bg-blue-600/30 text-blue-200">{pack.badge}</span>
            </div>
            <div class="text-xl font-semibold text-white">{format_number(Store.gems_for(pack))} Gems</div>
            <p :if={Store.promo_active?(pack)} class="text-sm text-green-300 mt-1">
              Includes {format_number(pack.bonus_gems)} bonus Gems
            </p>
            <div class="text-2xl text-white mt-4 mb-6">{Store.format_price(pack.price_cents, pack.currency)}</div>
            <button
              type="button"
              phx-click="buy"
              phx-value-product_id={pack.id}
              disabled={@can_buy != :ok or not @accepted? or not @open?}
              class="mt-auto w-full px-4 py-2 rounded bg-blue-600 hover:bg-blue-700 text-white font-semibold disabled:opacity-40 disabled:cursor-not-allowed"
            >
              Buy
            </button>
          </div>
        </div>

        <p :if={@packs == []} class="text-gray-500">Nothing is for sale right now.</p>

        <div class="mt-10 glass-dark rounded-lg p-5 border border-gray-700">
          <p :if={not @open?} class="text-yellow-300 mb-3">Purchases open soon.</p>
          <%= case @can_buy do %>
            <% :ok -> %>
              <form phx-change="accept_terms">
                <label class="flex items-start gap-3 text-gray-300">
                  <input type="hidden" name="accept" value="false" />
                  <input type="checkbox" name="accept" value="true" checked={@accepted?} class="mt-1" />
                  <span>
                    I understand that <strong class="text-white">all sales are final</strong>: Gems,
                    items and subscriptions are non-refundable, and Gems have no cash value.
                  </span>
                </label>
              </form>
            <% {:error, :not_signed_in} -> %>
              <p class="text-gray-400">
                <.link navigate={~p"/login"} class="text-blue-400 hover:underline">Sign in</.link> to buy Gems.
              </p>
            <% {:error, :email_unverified} -> %>
              <p class="text-gray-400">Verify your email address to buy Gems.</p>
            <% {:error, _} -> %>
              <p class="text-gray-400">Your account can't make purchases.</p>
          <% end %>
          <p class="text-xs text-gray-500 mt-3">
            Payment is handled by our payment provider on its own secure page; we never see your card.
          </p>
        </div>
      </div>
    </div>
    """
  end

  def format_number(n) when is_integer(n) do
    n |> Integer.to_string() |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  def format_number(_), do: "0"
end

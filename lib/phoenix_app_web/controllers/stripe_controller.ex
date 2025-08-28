defmodule PhoenixAppWeb.StripeController do
  use PhoenixAppWeb, :controller
  alias PhoenixApp.Commerce

  def webhook(conn, _params) do
    # Get the raw body for signature verification
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    
    # Get Stripe signature from headers
    stripe_signature = get_req_header(conn, "stripe-signature") |> List.first()
    
    # Verify webhook signature (you should set this in your config)
    webhook_secret = Application.get_env(:phoenix_app, :stripe_webhook_secret)
    
    case Stripe.Webhook.construct_event(body, stripe_signature, webhook_secret) do
      {:ok, %Stripe.Event{type: event_type, data: %{object: object}}} ->
        handle_stripe_event(event_type, object)
        
        conn
        |> put_status(:ok)
        |> json(%{received: true})
      
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  defp handle_stripe_event("payment_intent.succeeded", payment_intent) do
    # Handle successful payment
    case Commerce.get_order_by_stripe_payment_intent(payment_intent.id) do
      {:ok, order} ->
        Commerce.update_order(order, %{status: "processing"})
      
      {:error, _} ->
        # Log error - order not found
        :ok
    end
  end

  defp handle_stripe_event("payment_intent.payment_failed", payment_intent) do
    # Handle failed payment
    case Commerce.get_order_by_stripe_payment_intent(payment_intent.id) do
      {:ok, order} ->
        Commerce.update_order(order, %{status: "cancelled"})
      
      {:error, _} ->
        # Log error - order not found
        :ok
    end
  end

  defp handle_stripe_event(_event_type, _object) do
    # Handle other event types or ignore
    :ok
  end
end
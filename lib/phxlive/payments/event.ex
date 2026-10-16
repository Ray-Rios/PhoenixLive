defmodule Phxlive.Payments.Event do
  @moduledoc """
  A provider event, normalised. Providers turn their own webhooks into these;
  `Phxlive.Store` only ever sees this shape.

  `type`:
    * `:checkout_completed` - money taken for the checkout `provider_ref`
    * `:checkout_failed` - checkout expired or payment failed
    * `:dispute_opened`, `:dispute_won`, `:dispute_lost` - a chargeback's progress
  """
  @enforce_keys [:type, :provider, :provider_event_id, :provider_ref]
  defstruct [:type, :provider, :provider_event_id, :provider_ref, :amount_cents, :currency, raw: %{}]

  @type t :: %__MODULE__{
          type: :checkout_completed | :checkout_failed | :dispute_opened | :dispute_won | :dispute_lost,
          provider: String.t(),
          provider_event_id: String.t(),
          provider_ref: String.t(),
          amount_cents: integer() | nil,
          currency: String.t() | nil,
          raw: map()
        }
end

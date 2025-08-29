defmodule PhoenixApp.Accounts.UUID do
  @moduledoc """
  Simple UUID generator wrapper using Elixir's built-in `:crypto` and `Base`.
  """

  @doc "Generate a version 4 UUID"
  def generate do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)
    # Set version to 4 (random)
    c = Bitwise.bor(Bitwise.band(c, 0x0fff), 0x4000)
    # Set variant to 2
    d = Bitwise.bor(Bitwise.band(d, 0x3fff), 0x8000)

    [
      encode(a, 8), ?-, encode(b, 4), ?-, encode(c, 4), ?-, encode(d, 4), ?-, encode(e, 12)
    ]
    |> IO.iodata_to_binary()
  end

  defp encode(int, count) do
    int
    |> Integer.to_string(16)
    |> String.pad_leading(count, "0")
  end
end

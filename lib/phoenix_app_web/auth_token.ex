defmodule PhoenixAppWeb.AuthToken do
  @moduledoc """
  Simple JWT token generator using Joken or Phoenix.Token
  """

  # If you want to use Phoenix.Token (simpler)
  @salt "user auth salt"

  def generate(user) do
    # Encode the user ID into a token
    Phoenix.Token.sign(PhoenixAppWeb.Endpoint, @salt, %{user_id: user.id})
  end

  def verify(token) do
    case Phoenix.Token.verify(PhoenixAppWeb.Endpoint, @salt, token, max_age: 86400) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end
end

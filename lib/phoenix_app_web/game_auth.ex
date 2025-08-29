defmodule PhoenixAppWeb.GameAuth do
  @moduledoc """
  JWT authentication for game clients
  """
  
  use Joken.Config

  @impl Joken.Config
  def token_config do
    default_claims(default_exp: 24 * 60 * 60) # 24 hours
    |> add_claim("iss", fn -> "PhoenixApp" end)
  end

  def generate_jwt(user) do
    claims = %{
      "user_id" => user.id,
      "email" => user.email,
      "game_username" => user.name || user.email
    }
    
    case generate_and_sign(claims, get_signer()) do
      {:ok, token, _claims} -> {:ok, token}
      {:ok, token} -> {:ok, token}
      error -> error
    end
  end

  def verify_jwt(token) do
    case verify_and_validate(token, get_signer()) do
      {:ok, claims} ->
        {:ok, claims["user_id"]}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_signer do
    secret = Application.get_env(:phoenix_app, PhoenixAppWeb.Endpoint)[:secret_key_base]
    Joken.Signer.create("HS256", secret)
  end
end
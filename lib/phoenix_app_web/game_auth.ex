defmodule PhoenixAppWeb.GameAuth do
  @moduledoc """
  JWT authentication for game clients
  """
  
  use Joken.Config

  @impl Joken.Config
  def token_config do
    default_claims(default_exp: 24 * 60 * 60) # 24 hours
  end

  def generate_jwt(user) do
    claims = %{
      "user_id" => user.id,
      "email" => user.email,
      "game_username" => user.name || user.email  # Use 'name' field instead
    }
    
    generate_and_sign(claims)
  end

  def verify_jwt(token) do
    case verify_and_validate(token) do
      {:ok, claims} ->
        {:ok, claims["user_id"]}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp secret_key do
    Application.get_env(:phoenix_app, PhoenixAppWeb.Endpoint)[:secret_key_base]
  end
end
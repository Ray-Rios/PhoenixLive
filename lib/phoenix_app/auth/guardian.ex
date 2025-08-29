defmodule PhoenixApp.Auth.Guardian do
  use Guardian, otp_app: :phoenix_app

  # Tell Guardian how to encode a resource into a token
  @impl true
  def subject_for_token(%PhoenixApp.Accounts.User{id: id}, _claims) do
    {:ok, to_string(id)}
  end
  def subject_for_token(_, _), do: {:error, :no_resource}

  # Tell Guardian how to turn the subject back into a resource
  @impl true
  def resource_from_claims(%{"sub" => id}) do
    case PhoenixApp.Accounts.get_user!(id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
  def resource_from_claims(_), do: {:error, :no_claims}
end

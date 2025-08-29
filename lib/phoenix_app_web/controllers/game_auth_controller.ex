defmodule PhoenixAppWeb.GameAuthController do
  use PhoenixAppWeb, :controller

  alias PhoenixApp.Accounts
  alias PhoenixApp.Auth.Guardian

  ## LOGIN
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)

        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          token: token,
          user: %{
            id: user.id,
            email: user.email,
            username: user.username
          }
        })

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          errors: ["Invalid email or password"]
        })

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          errors: ["Authentication failed"]
        })
    end
  end

  ## REGISTER
  def register(conn, %{"email" => email, "password" => password, "username" => username}) do
    case Accounts.create_user(%{email: email, password: password, username: username}) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)

        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          token: token,
          user: %{
            id: user.id,
            email: user.email,
            username: user.username
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: format_changeset_errors(changeset)
        })

      {:error, {:jwt_error, _jwt_error}} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          errors: ["Token generation failed"]
        })
    end
  end

  ## ERROR FORMATTER
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, messages} ->
      "#{Atom.to_string(field)} #{Enum.join(messages, ", ")}"
    end)
  end
end

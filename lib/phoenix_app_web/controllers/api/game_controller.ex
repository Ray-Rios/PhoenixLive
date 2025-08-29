defmodule PhoenixAppWeb.Api.GameController do
  use PhoenixAppWeb, :controller

  alias PhoenixApp.Accounts
  alias PhoenixApp.Accounts.UserToken

  # ---------------------
  # POST /api/game/register
  # ---------------------
  def register(conn, params) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        {token, _user_token_struct} = UserToken.build_session_token(user)

        json(conn, %{
          "status" => "ok",
          "user" => %{
            "id" => user.id,
            "email" => user.email,
            "name" => user.name
          },
          "token" => Base.encode64(token)
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"status" => "error", "errors" => errors})
    end
  end

  # ---------------------
  # POST /api/game/login
  # ---------------------
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email(email) do
      nil ->
        send_invalid_login(conn)

      user ->
        if Accounts.check_password(user, password) do
          {token, _user_token_struct} = UserToken.build_session_token(user)

          json(conn, %{
            "status" => "ok",
            "user" => %{
              "id" => user.id,
              "email" => user.email,
              "name" => user.name
            },
            "token" => Base.encode64(token)
          })
        else
          send_invalid_login(conn)
        end
    end
  end

  # ---------------------
  # Helper: invalid login response
  # ---------------------
  defp send_invalid_login(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{"status" => "error", "errors" => %{"login" => "invalid email or password"}})
  end

  # ---------------------
  # Helper: format changeset errors
  # ---------------------
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # ---------------------
  # Example: you can add more endpoints here
  # ---------------------
  # def profile(conn, params), do: ...
end

defmodule PhoenixAppWeb.GameController do
  use PhoenixAppWeb, :controller

  alias PhoenixApp.Accounts
  alias PhoenixApp.Accounts.User

  # -------------------------
  # Register user
  # POST /api/game/register
  # -------------------------
  def register(conn, %{"email" => email, "name" => name, "password" => password}) do
    case Accounts.register_user(%{"email" => email, "name" => name, "password" => password}) do
      {:ok, user} ->
        json(conn, %{status: "success", user: sanitize_user(user)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: format_errors(changeset)})
    end
  end

  # -------------------------
  # Login
  # POST /api/game/login
  # -------------------------
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email(email) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", message: "Invalid credentials"})

      %User{} = user ->
        if Accounts.check_password(user, password) do
          json(conn, %{status: "success", user: sanitize_user(user)})
        else
          conn
          |> put_status(:unauthorized)
          |> json(%{status: "error", message: "Invalid credentials"})
        end
    end
  end

  # -------------------------
  # Update profile
  # PUT /api/game/profile/:id
  # -------------------------
  def update_profile(conn, %{"id" => id, "email" => email, "name" => name}) do
    user = Accounts.get_user!(id)

    case Accounts.update_profile(user, %{"email" => email, "name" => name}) do
      {:ok, user} ->
        json(conn, %{status: "success", user: sanitize_user(user)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: format_errors(changeset)})
    end
  end

  # -------------------------
  # Update password
  # PUT /api/game/password/:id
  # -------------------------
  def update_password(conn, %{"id" => id, "password" => password}) do
    user = Accounts.get_user!(id)

    case Accounts.update_password(user, %{"password" => password}) do
      {:ok, _user} ->
        json(conn, %{status: "success", message: "Password updated"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: format_errors(changeset)})
    end
  end

  # -------------------------
  # List all users (admin/debug)
  # GET /api/game/users
  # -------------------------
  def list_users(conn, _params) do
    users = Accounts.list_users()
    json(conn, %{status: "success", users: Enum.map(users, &sanitize_user/1)})
  end

  # -------------------------
  # Helpers
  # -------------------------
  defp sanitize_user(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      avatar_url: user.avatar_url,
      is_online: user.is_online,
      is_admin: user.is_admin,
      status: user.status
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

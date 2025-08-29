defmodule PhoenixAppWeb.GameAuthController do
  use PhoenixAppWeb, :controller

  alias PhoenixApp.Accounts
  alias PhoenixAppWeb.AuthToken

  # Helper to convert changeset errors to strings
  defp errors_to_map(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # ---------------------
  # Register new user
  # ---------------------
  def register(conn, %{"email" => email, "password" => password, "game_username" => username}) do
    attrs = %{
      email: email,
      password: password,
      name: username
    }

    case Accounts.register_user(attrs) do
      {:ok, user} ->
        token = AuthToken.generate(user)

        conn
        |> put_status(:created)
        |> json(%{
          message: "User registered successfully",
          user: %{
            id: user.id,
            email: user.email,
            name: user.name
          },
          token: token
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          message: "Registration failed",
          errors: errors_to_map(changeset)
        })
    end
  end

  # ---------------------
  # Login existing user
  # ---------------------
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email(email) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{message: "Invalid email or password"})

      user ->
        if Accounts.check_password(user, password) do
          token = AuthToken.generate(user)

          conn
          |> put_status(:ok)
          |> json(%{
            message: "Login successful",
            user: %{
              id: user.id,
              email: user.email,
              name: user.name
            },
            token: token
          })
        else
          conn
          |> put_status(:unauthorized)
          |> json(%{message: "Invalid email or password"})
        end
    end
  end
end

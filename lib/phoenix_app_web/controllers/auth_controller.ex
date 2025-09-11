defmodule PhoenixAppWeb.AuthController do
  use PhoenixAppWeb, :controller
  alias PhoenixApp.Accounts

  # Called when login succeeds
  def login_success(conn, %{"user_id" => user_id}) do
    case Accounts.get_user(user_id) do
      nil ->
        conn
        |> put_flash(:error, "User not found")
        |> redirect(to: ~p"/login")

      user ->
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: false) # true helps prevent session fixation
        |> redirect(to: ~p"/dashboard")
    end
  end

  # Logs out the user and returns them to homepage
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "You have been logged out")
    |> redirect(to: ~p"/")
  end
end

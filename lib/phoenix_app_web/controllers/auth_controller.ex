defmodule PhoenixAppWeb.AuthController do
  use PhoenixAppWeb, :controller
  alias PhoenixApp.Accounts

  def login_success(conn, %{"user_id" => user_id}) do
    case Accounts.get_user(user_id) do
      nil ->
        conn
        |> put_flash(:error, "User not found")
        |> redirect(to: ~p"/login")
      
      user ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Successfully logged in!")
        |> redirect(to: ~p"/dashboard")
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "You have been logged out")
    |> redirect(to: ~p"/")
  end
end
defmodule PhoenixApp.Accounts do
  alias PhoenixApp.Repo
  alias PhoenixApp.Accounts.User
  import Ecto.Changeset
  import Comeonin.Bcrypt, only: [hashpwsalt: 1, checkpw: 2]

  # ---------------------
  # Register a new user
  # ---------------------
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  # ---------------------
  # Get user by email
  # ---------------------
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  # ---------------------
  # Check user password
  # ---------------------
  def check_password(%User{password_hash: hash}, password) when is_binary(password) do
    checkpw(password, hash)
  end
end

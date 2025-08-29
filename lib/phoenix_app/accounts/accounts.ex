defmodule PhoenixApp.Accounts do
  alias PhoenixApp.Repo
  alias PhoenixApp.Accounts.User
  alias Bcrypt

  # ---------------------
  # List all users
  # ---------------------
  def list_users do
    Repo.all(User)
  end

  # ---------------------
  # Get User by id
  # ---------------------
  def get_user(id) when is_binary(id) do
    Repo.get(User, id)
  end

  def get_user!(id) do
    Repo.get!(User, id)
  end

  # ---------------------
  # Register a new user
  # ---------------------
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  # ---------------------
  # Update profile (name/email)
  # ---------------------
  def update_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  # ---------------------
  # Update password
  # ---------------------
  def update_password(%User{} = user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
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
    Bcrypt.verify_pass(password, hash)
  end
end

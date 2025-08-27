defmodule PhoenixApp.Resolvers.Accounts do
  alias PhoenixApp.Accounts


  def get_current_user(_parent, _args, %{context: %{current_user: user}}) do
    {:ok, user}
  end

  def get_current_user(_parent, _args, _resolution) do
    {:error, "Not authenticated"}
  end

  def register(_parent, %{input: input}, _resolution) do
    case Accounts.create_user(input) do
      {:ok, user} ->
        # Return user without JWT token since we're using session-based auth
        {:ok, %{user: user}}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def login(_parent, %{input: %{email: email, password: password}}, _resolution) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        # Return user without JWT token since we're using session-based auth
        {:ok, %{user: user}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def update_avatar(_parent, %{input: input}, %{context: %{current_user: user}}) do
    case Accounts.update_user(user, input) do
      {:ok, updated_user} ->
        {:ok, updated_user}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_avatar(_parent, _args, _resolution) do
    {:error, "Not authenticated"}
  end
end
defmodule PhoenixAppWeb.UserAuth do
  @moduledoc """
  Handles user authentication for LiveViews.
  """

  use Phoenix.Component
  import Phoenix.LiveView

  alias PhoenixApp.Accounts
  alias PhoenixAppWeb.Router.Helpers, as: Routes

  @doc """
  LiveView `on_mount` hook.

  Modes:
    * `:default` → assigns current_user if present (public pages).
    * `:require_authenticated_user` → assigns and redirects if missing.
    * `:require_admin_user` → assigns and redirects if missing or not admin.
  """
  def on_mount(:default, _params, session, socket) do
    socket = assign_current_user(socket, session)
    {:cont, socket}
  end

  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = assign_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt, push_navigate(socket, to: Routes.auth_path(socket, :login))}
    end
  end

  def on_mount(:require_admin_user, _params, session, socket) do
    socket = assign_current_user(socket, session)

    cond do
      socket.assigns.current_user == nil ->
        {:halt, push_navigate(socket, to: Routes.auth_path(socket, :login))}

      not socket.assigns.current_user.is_admin ->
        {:halt, push_navigate(socket, to: Routes.page_path(socket, :index))}

      true ->
        {:cont, socket}
    end
  end

  # --- Helpers ---

  defp assign_current_user(socket, %{"user_id" => user_id}) do
    assign_new(socket, :current_user, fn ->
      Accounts.get_user(user_id)
    end)
  end

  defp assign_current_user(socket, _session) do
    assign_new(socket, :current_user, fn -> nil end)
  end
end

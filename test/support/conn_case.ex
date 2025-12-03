defmodule PhoenixAppWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on Phoenix.ConnTest and the SQL sandbox
  for isolated DB access.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      use Phoenix.ConnTest

      alias PhoenixApp.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query

      # Provide LiveView testing helpers automatically for ConnCase users
      import Phoenix.LiveViewTest

      # Include VerifiedRoutes so tests can use the ~p sigil and Routes without
      # relying on a generated Router.Helpers module. This mirrors the app
      # setup (unquote(verified_routes())) so tests and app code use the same
      # route helpers.
      unquote(PhoenixAppWeb.verified_routes())

      @endpoint PhoenixAppWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PhoenixApp.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(PhoenixApp.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

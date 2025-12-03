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

      # In older Phoenix versions tests imported Router.Helpers or aliased Routes.
      # This project uses Phoenix.VerifiedRoutes / `helpers: false` in the router
      # so the generated Router.Helpers module may not exist at compile time.
      # Tests should prefer the ~p sigil or use explicit paths instead of
      # importing a missing Router.Helpers module here.

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

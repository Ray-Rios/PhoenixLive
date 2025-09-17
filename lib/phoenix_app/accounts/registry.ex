defmodule PhoenixApp.Accounts.Registry do
  @moduledoc false
  use Ash.Registry

  entries do
    entry PhoenixApp.Accounts.User
  end
end

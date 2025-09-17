defmodule PhoenixApp.Api do
  use Ash.Api

  resources do
    registry PhoenixApp.Accounts.Registry
  end
end

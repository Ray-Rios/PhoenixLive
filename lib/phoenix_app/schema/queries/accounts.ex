defmodule PhoenixApp.Schema.Queries.Accounts do
  use Absinthe.Schema.Notation
  alias PhoenixApp.Resolvers.Accounts, as: AccountsResolver

  object :accounts_queries do
    @desc "Get the current logged-in user"
    field :me, :user do
      resolve &AccountsResolver.get_current_user/3
    end
  end
end

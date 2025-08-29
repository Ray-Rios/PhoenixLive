defmodule PhoenixApp.Schema do
  use Absinthe.Schema
  import_types PhoenixApp.Schema.ContentTypes
  import_types PhoenixApp.Schema.Types.Inputs
  import_types PhoenixApp.Schema.Queries.Accounts
  import_types PhoenixApp.Schema.Mutations.Accounts

  alias PhoenixApp.Resolvers

  query do
    import_fields :accounts_queries
    @desc "Get all pages"
    field :pages, list_of(:page) do
      resolve &Resolvers.Content.list_pages/3
    end

    @desc "Get a page by ID"
    field :page, :page do
      arg :id, non_null(:id)
      resolve &Resolvers.Content.get_page/3
    end

    @desc "Get current user"
    field :me, :user do
      resolve &Resolvers.Accounts.get_current_user/3
    end
  end

  mutation do
    import_fields :accounts_mutations
    @desc "Create a new page"
    field :create_page, :page do
      arg :input, non_null(:page_input)
      resolve &Resolvers.Content.create_page/3
    end

    @desc "Update a page"
    field :update_page, :page do
      arg :id, non_null(:id)
      arg :input, non_null(:page_input)
      resolve &Resolvers.Content.update_page/3
    end

    @desc "Delete a page"
    field :delete_page, :boolean do
      arg :id, non_null(:id)
      resolve &Resolvers.Content.delete_page/3
    end

    @desc "Register a new user"
    field :register, :auth_payload do
      arg :input, non_null(:register_input)
      resolve &Resolvers.Accounts.register/3
    end

    @desc "Login user"
    field :login, :auth_payload do
      arg :input, non_null(:login_input)
      resolve &Resolvers.Accounts.login/3
    end

    @desc "Update user avatar"
    field :update_avatar, :user do
      arg :input, non_null(:avatar_input)
      resolve &Resolvers.Accounts.update_avatar/3
    end
  end

  subscription do
    @desc "Subscribe to chat messages"
    field :message_added, :chat_message do
      config fn _args, %{context: context} ->
        case context[:current_user] do
          %{id: _user_id} -> {:ok, topic: "chat:lobby"}
          _ -> {:error, "Must be logged in"}
        end
      end
    end

    @desc "Subscribe to user presence updates"
    field :user_presence, :presence_update do
      config fn _args, %{context: context} ->
        case context[:current_user] do
          %{id: _user_id} -> {:ok, topic: "presence:lobby"}
          _ -> {:error, "Must be logged in"}
        end
      end
    end
  end
end
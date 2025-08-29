defmodule PhoenixApp.Schema.Types.Inputs do
  use Absinthe.Schema.Notation

  # Input for registering a user
  input_object :register_input do
    field :email, non_null(:string)
    field :password, non_null(:string)
    field :name, :string
  end

  # Input for login
  input_object :login_input do
    field :email, non_null(:string)
    field :password, non_null(:string)
  end

  # Input for updating avatar
  input_object :avatar_input do
    field :user_id, non_null(:id)
    field :avatar_url, :string
    field :avatar_shape, :string
    field :avatar_color, :string
  end
end

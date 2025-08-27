defmodule PhoenixApp.Schema.ContentTypes do
  use Absinthe.Schema.Notation

  object :page do
    field :id, :id
    field :title, :string
    field :slug, :string
    field :content, :string
    field :template_type, :string
    field :is_published, :boolean
    field :inserted_at, :string
    field :updated_at, :string
  end

  object :user do
    field :id, :id
    field :email, :string
    field :name, :string
    field :avatar_shape, :string
    field :avatar_color, :string
    field :is_online, :boolean
    field :is_admin, :boolean
    field :inserted_at, :string
  end

  object :auth_payload do
    field :token, :string
    field :user, :user
  end

  object :chat_message do
    field :id, :id
    field :content, :string
    field :user, :user
    field :inserted_at, :string
  end

  object :presence_update do
    field :user_id, :id
    field :status, :string
    field :user, :user
  end

  input_object :page_input do
    field :title, non_null(:string)
    field :slug, :string
    field :content, :string
    field :template_type, :string
    field :is_published, :boolean
  end

  input_object :register_input do
    field :email, non_null(:string)
    field :password, non_null(:string)
    field :name, :string
  end

  input_object :login_input do
    field :email, non_null(:string)
    field :password, non_null(:string)
  end

  input_object :avatar_input do
    field :avatar_shape, non_null(:string)
    field :avatar_color, non_null(:string)
  end

  input_object :chat_input do
    field :content, non_null(:string)
  end
end
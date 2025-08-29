defmodule PhoenixApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Comeonin.Bcrypt

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :name, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :avatar_shape, :string, default: "circle"
    field :avatar_color, :string, default: "#3B82F6"
    field :avatar_file, PhoenixApp.Avatar.Type
    field :avatar_url, :string
    field :is_online, :boolean, default: false
    field :is_admin, :boolean, default: true
    field :status, :string, default: "active"
    field :two_factor_secret, :string
    field :two_factor_enabled, :boolean, default: false
    field :two_factor_backup_codes, {:array, :string}, default: []
    field :position_x, :float, default: 400.0
    field :position_y, :float, default: 300.0
    field :last_activity, :utc_datetime

    has_many :orders, PhoenixApp.Commerce.Order
    has_many :posts, PhoenixApp.Content.Post
    has_many :files, PhoenixApp.Files.UserFile
    has_many :chat_messages, PhoenixApp.Chat.Message

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password])
    |> validate_required([:email, :password])
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    if pwd = get_change(changeset, :password) do
      put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(pwd))
    else
      changeset
    end
  end
end

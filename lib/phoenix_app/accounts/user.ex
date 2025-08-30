defmodule PhoenixApp.Accounts.User do
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset
  alias Bcrypt

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

  # Registration (new user)
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password])
    |> validate_required([:email, :password])
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  # Update profile (email/name)
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
  end

  # Update password only
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 6)
    |> put_password_hash()
  end

  # Admin changeset
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:is_admin])
    |> validate_required([:is_admin])
  end

  # Avatar changeset
  def avatar_changeset(user, attrs) do
    user
    |> cast(attrs, [:avatar_shape, :avatar_color, :avatar_url])
    |> cast_attachments(attrs, [:avatar_file])
  end

  # Position changeset
  def position_changeset(user, attrs) do
    user
    |> cast(attrs, [:position_x, :position_y])
    |> validate_number(:position_x, greater_than_or_equal_to: 0)
    |> validate_number(:position_y, greater_than_or_equal_to: 0)
  end

  # Status changeset
  def status_changeset(user, attrs) do
    user
    |> cast(attrs, [:status, :is_active])
  end

  # Two-factor authentication changeset
  def two_factor_changeset(user, attrs) do
    user
    |> cast(attrs, [:two_factor_secret, :two_factor_enabled, :two_factor_backup_codes])
  end

  # Password validation
  def valid_password?(%__MODULE__{password_hash: hash}, password) when is_binary(password) do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_password?(_, _), do: false

  # Two-factor authentication helpers
  def generate_two_factor_secret do
    :crypto.strong_rand_bytes(20) |> Base.encode32()
  end

  def generate_backup_codes do
    for _ <- 1..10, do: :crypto.strong_rand_bytes(4) |> Base.encode16()
  end

  # Internal helper
  defp put_password_hash(changeset) do
    if pwd = get_change(changeset, :password) do
      put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(pwd))
    else
      changeset
    end
  end
end

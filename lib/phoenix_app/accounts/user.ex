defmodule PhoenixApp.Accounts.User do
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset

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

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :name, :avatar_shape, :avatar_color, :status])
    |> put_name_from_email()
    |> validate_required([:email, :password, :name])
    |> validate_email()
    |> validate_password()
    |> validate_length(:name, min: 1, max: 20)
    |> validate_inclusion(:status, ["active", "disabled"])
    |> maybe_hash_password()
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :avatar_shape, :avatar_color, :avatar_url])
    |> cast_attachments(attrs, [:avatar_file])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 20)
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password()
    |> maybe_hash_password()
  end

  def two_factor_changeset(user, attrs) do
    user
    |> cast(attrs, [:two_factor_secret, :two_factor_enabled, :two_factor_backup_codes])
  end

  def position_changeset(user, attrs) do
    user
    |> cast(attrs, [:position_x, :position_y])
    |> validate_number(:position_x, greater_than_or_equal_to: 0)
    |> validate_number(:position_y, greater_than_or_equal_to: 0)
  end

  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:is_admin, :status])
    |> validate_inclusion(:status, ["active", "disabled"])
  end

  def confirm_changeset(user) do
    user
    |> change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def avatar_changeset(user, attrs) do
    user
    |> cast(attrs, [:avatar_shape, :avatar_color])
    |> validate_required([:avatar_shape, :avatar_color])
  end

  def online_changeset(user, is_online) do
    user
    |> change(is_online: is_online, last_activity: DateTime.utc_now())
  end

  defp put_name_from_email(changeset) do
    case get_change(changeset, :name) do
      nil ->
        email = get_change(changeset, :email) || get_field(changeset, :email)
        if email, do: put_change(changeset, :name, email), else: changeset
      _ -> changeset
    end
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, PhoenixApp.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
  end

  defp maybe_hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      changeset
      |> validate_length(:password, min: 8, max: 72)
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  def valid_password?(%PhoenixApp.Accounts.User{password_hash: password_hash}, password)
      when is_binary(password_hash) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, password_hash)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  def generate_two_factor_secret do
    :pot.hotp_secret_base32()
  end

  def generate_backup_codes do
    for _ <- 1..10, do: :crypto.strong_rand_bytes(8) |> Base.encode32(padding: false)
  end

  def verify_two_factor_token(user, token) do
    if user.two_factor_enabled and user.two_factor_secret do
      :pot.valid_totp(token, user.two_factor_secret, window: 1)
    else
      false
    end
  end
end
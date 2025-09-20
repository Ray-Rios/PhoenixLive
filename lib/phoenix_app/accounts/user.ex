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
    field :role, :string, default: "subscriber"
    field :two_factor_secret, :string
    field :two_factor_enabled, :boolean, default: false
    field :two_factor_backup_codes, {:array, :string}, default: []
    field :position_x, :float, default: 400.0
    field :position_y, :float, default: 300.0
    field :last_activity, :utc_datetime

    has_many :orders, PhoenixApp.Commerce.Order
    has_many :posts, PhoenixApp.Content.Post
    has_many :comments, PhoenixApp.Content.Comment
    has_many :files, PhoenixApp.Files.UserFile
    has_many :chat_messages, PhoenixApp.Chat.Message
    
    # Game relationships
    has_many :game_sessions, PhoenixApp.Game.GameSession
    has_many :game_events, PhoenixApp.Game.GameEvent, foreign_key: :player_id
    has_one :player_stats, PhoenixApp.Game.PlayerStats

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

  # Update profile (email/name/avatar)
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :avatar_shape, :avatar_color, :avatar_url, :role])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_inclusion(:role, ["administrator", "editor", "author", "contributor", "subscriber"])
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
    Pbkdf2.verify_pass(password, hash)
  end

  def valid_password?(_, _), do: false

  # Two-factor authentication helpers
  def generate_two_factor_secret do
    :crypto.strong_rand_bytes(20) |> Base.encode32()
  end

  def generate_backup_codes do
    for _ <- 1..10, do: :crypto.strong_rand_bytes(4) |> Base.encode16()
  end

  # CMS Role capabilities (integrated from CMS system)
  def get_capabilities(%__MODULE__{role: role}) do
    case role do
      "administrator" -> [
        "manage_options", "edit_posts", "edit_others_posts", "edit_published_posts",
        "publish_posts", "delete_posts", "delete_others_posts", "delete_published_posts",
        "edit_pages", "edit_others_pages", "edit_published_pages", "publish_pages",
        "delete_pages", "delete_others_pages", "delete_published_pages",
        "manage_categories", "manage_links", "moderate_comments", "upload_files",
        "import", "unfiltered_html", "edit_themes", "install_themes", "update_themes",
        "delete_themes", "edit_plugins", "install_plugins", "update_plugins",
        "delete_plugins", "edit_users", "list_users", "delete_users", "promote_users",
        "remove_users", "add_users", "create_users", "edit_dashboard", "update_core",
        "list_roles", "promote_users", "edit_theme_options", "delete_site", "manage_network",
        "manage_sites", "manage_network_users", "manage_network_plugins", "manage_network_themes",
        "manage_network_options", "upgrade_network", "setup_network"
      ]
      "editor" -> [
        "edit_posts", "edit_others_posts", "edit_published_posts", "publish_posts",
        "delete_posts", "delete_others_posts", "delete_published_posts",
        "edit_pages", "edit_others_pages", "edit_published_pages", "publish_pages",
        "delete_pages", "delete_others_pages", "delete_published_pages",
        "manage_categories", "manage_links", "moderate_comments", "upload_files",
        "unfiltered_html"
      ]
      "author" -> [
        "edit_posts", "edit_published_posts", "publish_posts", "delete_posts",
        "delete_published_posts", "upload_files"
      ]
      "contributor" -> [
        "edit_posts", "delete_posts"
      ]
      "subscriber" -> [
        "read"
      ]
      _ -> []
    end
  end

  def can?(%__MODULE__{} = user, capability) do
    capability in get_capabilities(user)
  end

  # Internal helper
  defp put_password_hash(changeset) do
    if pwd = get_change(changeset, :password) do
      hash = Pbkdf2.hash_pwd_salt(pwd)
      put_change(changeset, :password_hash, hash)
    else
      changeset
    end
  end
end

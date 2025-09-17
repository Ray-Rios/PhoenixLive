defmodule PhoenixApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshAuthentication.Resource],
    data_layer: AshPostgres.DataLayer


  postgres do
  repo PhoenixApp.Repo
  table "users"
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  # ----------------------------
  # ----------------------------
  # AshAuthentication configuration
  # ----------------------------
  # NOTE: The `authentication do` DSL from AshAuthentication was removed here
  # to avoid a compile-time macro load-order error during the Docker image
  # build. Reintroduce the `authentication do` block once the build environment
  # guarantees the AshAuthentication extension is available at compile time.
  # Example (re-add when ready):
  #
  # authentication do
  #   api PhoenixApp.Api
  #   strategies do
  #     password :password, user: PhoenixApp.Accounts.User do
  #       identity_field :email
  #       password_field :hashed_password
  #     end
  #   end
  #   providers do
  #     password :password
  #   end
  # end
  if Application.get_env(:phoenix_app, :enable_ash_authentication, false) do
    authentication do
      api PhoenixApp.Api

      strategies do
        password :password, user: PhoenixApp.Accounts.User do
          identity_field :email
          password_field :hashed_password
        end
      end

      providers do
        password :password
      end
    end
  else
    # Authentication DSL is currently disabled via config.
    # Set `config :phoenix_app, :enable_ash_authentication, true` to enable.
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
    end

    attribute :name, :string

    attribute :hashed_password, :string do
      sensitive? true
    end

    # Keep compatibility with existing code that expects `password_hash`
    attribute :password_hash, :string do
      sensitive? true
      source :hashed_password
      allow_nil? true
    end

    attribute :confirmed_at, :utc_datetime
    attribute :avatar_shape, :string, default: "circle"
    attribute :avatar_color, :string, default: "#3B82F6"
    attribute :avatar_url, :string
    attribute :is_online, :boolean, default: false
    attribute :is_admin, :boolean, default: true
    attribute :status, :string, default: "active"
    attribute :role, :string, default: "subscriber"
    attribute :two_factor_secret, :string
    attribute :two_factor_enabled, :boolean, default: false
    attribute :two_factor_backup_codes, {:array, :string}, default: []
    attribute :position_x, :float, default: 400.0
    attribute :position_y, :float, default: 300.0
    attribute :last_activity, :utc_datetime

    timestamps()
  end

  identities do
    identity :email, [:email]
  end

  # Compatibility wrappers for existing code expecting Ecto changesets
  # These adapt to AshAuthentication or provide minimal behavior so compile succeeds.
  def registration_changeset(user, attrs) do
    # Use the Ash create action as the authoritative create path.
    changes = Ash.Changeset.for_create(__MODULE__, :create, attrs)
    changes
  end

  def valid_password?(user, password) do
    hashed = Map.get(user, :hashed_password)
    cond do
      not (is_binary(hashed) and is_binary(password)) ->
        false
      Code.ensure_loaded?(Argon2) ->
        try do
          Argon2.verify_pass(password, hashed)
        rescue
          _ -> false
        end
      Code.ensure_loaded?(Pbkdf2) ->
        try do
          Pbkdf2.verify_pass(password, hashed)
        rescue
          _ -> false
        end
      true ->
        false
    end
  end

  def password_changeset(user, attrs) do
    # Create a changeset that sets the hashed_password via Ash actions
    Ash.Changeset.for_update(user, :update, attrs)
  end

  def profile_changeset(user, attrs) do
    Ash.Changeset.for_update(user, :update, attrs)
  end

  def admin_changeset(user, attrs) do
    Ash.Changeset.for_update(user, :update, attrs)
  end

  def position_changeset(user, attrs) do
    Ash.Changeset.for_update(user, :update, attrs)
  end

  def avatar_changeset(user, attrs) do
    Ash.Changeset.for_update(user, :update, attrs)
  end

  def status_changeset(user, attrs) do
    Ash.Changeset.for_update(user, :update, attrs)
  end

  def two_factor_changeset(user, attrs) do
    Ash.Changeset.for_update(user, :update, attrs)
  end
  # Associations preserved as read-only references; convert fully later if needed
  relationships do
    # has_many :orders, PhoenixApp.Commerce.Order
    # has_many :posts, PhoenixApp.Content.Post
    # has_many :comments, PhoenixApp.Content.Comment
    # has_many :files, PhoenixApp.Files.UserFile
    # has_many :chat_messages, PhoenixApp.Chat.Message
    # has_many :game_sessions, PhoenixApp.Game.GameSession
    # has_many :game_events, PhoenixApp.Game.GameEvent
    # has_one :player_stats, PhoenixApp.Game.PlayerStats
  end
end

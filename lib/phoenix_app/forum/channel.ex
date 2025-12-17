defmodule PhoenixApp.Forum.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chat_channels" do
    field :name, :string
    field :description, :string
    field :topic, :string
    field :is_private, :boolean, default: false
    field :position, :integer, default: 0
    field :channel_type, :string, default: "text" # text, voice, video, stream

    # User ownership fields
    field :owner_id, :binary_id
    field :is_public, :boolean, default: true
    field :is_user_created, :boolean, default: false
    field :max_participants, :integer, default: 50
    field :invite_code, :string
    field :settings, :map, default: %{}
    field :icon_path, :string

    # Legacy field - keeping for backwards compatibility
    field :created_by_id, :binary_id
    
    belongs_to :owner, PhoenixApp.Accounts.User, define_field: false, foreign_key: :owner_id
    belongs_to :creator, PhoenixApp.Accounts.User, define_field: false, foreign_key: :created_by_id, type: :binary_id

    has_many :messages, PhoenixApp.Forum.Message
    has_many :members, PhoenixApp.Forum.ChannelMember
    has_many :streaming_sessions, PhoenixApp.Forum.StreamingSession

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :description, :topic, :is_private, :position, :channel_type, :created_by_id, :owner_id, :is_public, :is_user_created, :max_participants, :invite_code, :settings, :icon_path])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:channel_type, ["text", "voice", "video", "stream"])
    |> unique_constraint(:name)
    |> unique_constraint(:invite_code)
    |> validate_channel_limit()
    |> maybe_generate_invite_code()
  end

  defp validate_channel_limit(changeset) do
    case get_change(changeset, :owner_id) do
      nil -> 
        changeset
      owner_id ->
        # Only validate limit for user-created channels
        if get_field(changeset, :is_user_created) do
          import Ecto.Query
          
          count = PhoenixApp.Repo.aggregate(
            from(c in __MODULE__, where: c.owner_id == ^owner_id and c.is_user_created == true),
            :count
          )
          
          if count >= 5 && is_nil(get_field(changeset, :id)) do
            add_error(changeset, :owner_id, "You can only create up to 5 channels")
          else
            changeset
          end
        else
          changeset
        end
    end
  end

  defp maybe_generate_invite_code(changeset) do
    # Only generate invite code for private user-created channels
    if get_field(changeset, :is_user_created) && !get_field(changeset, :is_public) && is_nil(get_field(changeset, :invite_code)) do
      put_change(changeset, :invite_code, generate_invite_code())
    else
      changeset
    end
  end

  defp generate_invite_code do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false) |> binary_part(0, 10)
  end
end
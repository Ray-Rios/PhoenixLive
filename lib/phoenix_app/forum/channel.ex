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
    field :channel_type, :string, default: "text" # text, voice, video

  # optional reference to the user who created the channel
  field :created_by_id, :binary_id
  belongs_to :creator, PhoenixApp.Accounts.User, define_field: false, foreign_key: :created_by_id, type: :binary_id

  has_many :messages, PhoenixApp.Forum.Message

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
  |> cast(attrs, [:name, :description, :topic, :is_private, :position, :channel_type, :created_by_id])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:channel_type, ["text", "voice", "video"])
    |> unique_constraint(:name)
  end
end
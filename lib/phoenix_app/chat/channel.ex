defmodule PhoenixApp.Chat.Channel do
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

    has_many :messages, PhoenixApp.Chat.Message

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :description, :topic, :is_private, :position, :channel_type])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:channel_type, ["text", "voice", "video"])
    |> unique_constraint(:name)
  end
end
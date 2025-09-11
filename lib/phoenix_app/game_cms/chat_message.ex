defmodule PhoenixApp.GameCMS.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_chat_messages" do
    field :message, :string
    field :channel, :string, default: "global"
    field :message_type, :string, default: "chat"

    belongs_to :user, PhoenixApp.Accounts.User
    belongs_to :character, PhoenixApp.GameCMS.Character, on_replace: :nilify

    timestamps()
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:message, :channel, :message_type, :user_id, :character_id])
    |> validate_required([:message, :user_id])
    |> validate_length(:message, min: 1, max: 500)
    |> validate_inclusion(:channel, ["global", "guild", "party", "whisper", "system"])
    |> validate_inclusion(:message_type, ["chat", "system", "emote", "command"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:character_id)
  end
end
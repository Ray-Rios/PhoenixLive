defmodule PhoenixApp.GameCMS.GameEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_events" do
    field :event_type, :string
    field :message, :string
    field :data, :map, default: %{}
    field :severity, :string, default: "info"

    belongs_to :user, PhoenixApp.Accounts.User, on_replace: :nilify
    belongs_to :character, PhoenixApp.GameCMS.Character, on_replace: :nilify

    timestamps()
  end

  @doc false
  def changeset(game_event, attrs) do
    game_event
    |> cast(attrs, [:event_type, :message, :data, :severity, :user_id, :character_id])
    |> validate_required([:event_type, :message])
    |> validate_inclusion(:event_type, [
      "player_join", "player_leave", "level_up", "quest_complete", 
      "item_found", "combat", "death", "guild_join", "guild_leave",
      "chat_message", "system_message", "admin_action"
    ])
    |> validate_inclusion(:severity, ["info", "warning", "error", "success"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:character_id)
  end
end
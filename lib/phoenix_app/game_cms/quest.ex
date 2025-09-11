defmodule PhoenixApp.GameCMS.Quest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_quests" do
    field :title, :string
    field :description, :string
    field :objective, :string
    field :difficulty, :string, default: "easy"
    field :level_requirement, :integer, default: 1
    field :xp_reward, :integer, default: 100
    field :gold_reward, :integer, default: 50
    field :item_rewards, {:array, :integer}, default: []
    field :prerequisites, {:array, :integer}, default: []
    field :zone, :string
    field :npc_giver, :string
    field :active, :boolean, default: true
    field :repeatable, :boolean, default: false
    field :max_completions, :integer, default: 1

    timestamps()
  end

  @doc false
  def changeset(quest, attrs) do
    quest
    |> cast(attrs, [
      :title, :description, :objective, :difficulty, :level_requirement,
      :xp_reward, :gold_reward, :item_rewards, :prerequisites,
      :zone, :npc_giver, :active, :repeatable, :max_completions
    ])
    |> validate_required([:title, :description, :objective])
    |> validate_length(:title, min: 5, max: 100)
    |> validate_length(:description, min: 10, max: 1000)
    |> validate_inclusion(:difficulty, ["easy", "medium", "hard", "expert", "legendary"])
    |> validate_number(:level_requirement, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:xp_reward, greater_than_or_equal_to: 0)
    |> validate_number(:gold_reward, greater_than_or_equal_to: 0)
    |> validate_number(:max_completions, greater_than: 0)
  end
end
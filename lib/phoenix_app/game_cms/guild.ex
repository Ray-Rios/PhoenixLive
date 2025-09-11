defmodule PhoenixApp.GameCMS.Guild do
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_guilds" do
    field :name, :string
    field :description, :string
    field :level, :integer, default: 1
    field :experience, :integer, default: 0
    field :max_members, :integer, default: 50
    field :guild_type, :string, default: "casual"
    field :requirements, :string
    field :active, :boolean, default: true

    belongs_to :leader, PhoenixApp.Accounts.User
    has_many :characters, PhoenixApp.GameCMS.Character

    timestamps()
  end

  @doc false
  def changeset(guild, attrs) do
    guild
    |> cast(attrs, [
      :name, :description, :level, :experience, :max_members,
      :guild_type, :requirements, :active, :leader_id
    ])
    |> validate_required([:name, :leader_id])
    |> validate_length(:name, min: 3, max: 50)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:guild_type, ["casual", "competitive", "roleplay", "hardcore"])
    |> validate_number(:level, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:max_members, greater_than: 0, less_than_or_equal_to: 200)
    |> unique_constraint(:name)
    |> foreign_key_constraint(:leader_id)
  end
end
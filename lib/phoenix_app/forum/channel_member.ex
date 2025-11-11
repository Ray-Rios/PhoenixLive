defmodule PhoenixApp.Forum.ChannelMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "channel_members" do
    belongs_to :channel, PhoenixApp.Forum.Channel
    belongs_to :user, PhoenixApp.Accounts.User
    
    field :role, :string, default: "member" # owner, admin, moderator, member
    field :nickname, :string
    field :is_muted, :boolean, default: false
    field :is_banned, :boolean, default: false
    field :joined_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:channel_id, :user_id, :role, :nickname, :is_muted, :is_banned, :joined_at])
    |> validate_required([:channel_id, :user_id])
    |> validate_inclusion(:role, ["owner", "admin", "moderator", "member"])
    |> unique_constraint([:channel_id, :user_id])
    |> maybe_set_joined_at()
  end

  defp maybe_set_joined_at(changeset) do
    if is_nil(get_field(changeset, :joined_at)) do
      put_change(changeset, :joined_at, DateTime.utc_now())
    else
      changeset
    end
  end
end

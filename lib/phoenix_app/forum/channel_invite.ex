defmodule PhoenixApp.Forum.ChannelInvite do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "channel_invites" do
    belongs_to :channel, PhoenixApp.Forum.Channel
    belongs_to :inviter, PhoenixApp.Accounts.User
    
    field :code, :string
    field :max_uses, :integer
    field :uses, :integer, default: 0
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:channel_id, :inviter_id, :code, :max_uses, :uses, :expires_at])
    |> validate_required([:channel_id, :inviter_id, :code])
    |> unique_constraint(:code)
    |> maybe_generate_code()
  end

  defp maybe_generate_code(changeset) do
    if is_nil(get_field(changeset, :code)) do
      put_change(changeset, :code, generate_code())
    else
      changeset
    end
  end

  defp generate_code do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false) |> binary_part(0, 10)
  end

  def is_valid?(%__MODULE__{} = invite) do
    # Check if not expired
    not_expired = is_nil(invite.expires_at) || DateTime.compare(DateTime.utc_now(), invite.expires_at) == :lt
    
    # Check if not at max uses
    not_maxed = is_nil(invite.max_uses) || invite.uses < invite.max_uses
    
    not_expired && not_maxed
  end
end

defmodule PhoenixApp.Forum.ChannelMemberTest do
  use ExUnit.Case, async: true

  alias PhoenixApp.Forum.ChannelMember

  test "changeset allows 'banned' role" do
    attrs = %{channel_id: Ecto.UUID.generate(), user_id: Ecto.UUID.generate(), role: "banned"}
    changeset = ChannelMember.changeset(%ChannelMember{}, attrs)

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :role) == "banned"
  end

  test "changeset defaults joined_at when nil" do
    attrs = %{channel_id: Ecto.UUID.generate(), user_id: Ecto.UUID.generate(), role: "member"}
    changeset = ChannelMember.changeset(%ChannelMember{}, attrs)

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :joined_at) != nil
  end
end

defmodule PhoenixApp.Forum.PermissionsTest do
  use ExUnit.Case, async: true

  alias PhoenixApp.Forum
  alias PhoenixApp.Forum.Channel

  describe "can_manage_channel?/2" do
    test "returns false for nil user" do
      assert Forum.can_manage_channel?(nil, %{}) == false
    end

    test "returns true for site admins" do
      user = %{id: "u1", is_admin: true}
      channel = %Channel{id: "c1", owner_id: nil, created_by_id: nil}

      assert Forum.can_manage_channel?(user, channel)
    end

    test "returns true for owner or creator" do
      user = %{id: "u42"}
      channel_owner = %Channel{id: "c2", owner_id: "u42", created_by_id: nil}
      channel_creator = %Channel{id: "c3", owner_id: nil, created_by_id: "u42"}

      assert Forum.can_manage_channel?(user, channel_owner)
      assert Forum.can_manage_channel?(user, channel_creator)
    end
  end

  describe "can_moderate_channel?/2" do
    test "returns false for nil user" do
      assert Forum.can_moderate_channel?(nil, %{}) == false
    end

    test "returns true for site admins" do
      user = %{id: "u1", is_admin: true}
      channel = %Channel{id: "c1"}

      assert Forum.can_moderate_channel?(user, channel)
    end
  end

  describe "can_invite_to_channel?/2" do
    test "returns false for nil user" do
      assert Forum.can_invite_to_channel?(nil, %{}) == false
    end

    test "returns true for admins" do
      user = %{id: "u1", is_admin: true}
      channel = %Channel{id: "c1"}

      assert Forum.can_invite_to_channel?(user, channel)
    end
  end

  describe "transfer_channel_ownership/3 authorization" do
    test "forbidden when caller is not owner, creator or admin" do
      user = %{id: "u1", is_admin: false}
      channel = %Channel{id: "c1", owner_id: "someone_else", created_by_id: "someone_else"}

      assert {:error, :forbidden} = Forum.transfer_channel_ownership(user, channel, "new_owner")
    end

    # NOTE: full transfer_channel_ownership success path requires DB and is covered by integrations.
  end
end

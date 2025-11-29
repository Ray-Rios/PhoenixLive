defmodule PhoenixApp.Forum.MembersAndInvitesTest do
  use ExUnit.Case, async: false

  alias PhoenixApp.{Forum, Accounts, Repo}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  defp user_attrs(email, name) do
    %{
      email: email,
      name: name,
      password: "Test@1234"
    }
  end

  test "create_personal_invite resolves username/email to user id" do
    {:ok, inviter} = Accounts.create_user(user_attrs("inviter@example.com", "inviter_user"))
    {:ok, invitee} = Accounts.create_user(user_attrs("invitee@example.com", "invitee_user"))

    # create a channel with inviter as owner
    {:ok, channel} = Forum.create_channel(%{"name" => "ci-channel", "owner_id" => inviter.id, "created_by_id" => inviter.id})

    # invite by email
    assert {:ok, invite_by_email} = Forum.create_personal_invite(inviter.id, invitee.email, channel.id)
    assert invite_by_email.invitee_id == invitee.id

    # invite by username
    assert {:ok, invite_by_name} = Forum.create_personal_invite(inviter.id, invitee.name, channel.id)
    assert invite_by_name.invitee_id == invitee.id
  end

  test "list_channel_members includes owner and pending invitees" do
    {:ok, owner} = Accounts.create_user(user_attrs("owner@example.com", "owner_user"))
    {:ok, invited} = Accounts.create_user(user_attrs("invited@example.com", "invited_user"))
    {:ok, channel} = Forum.create_channel(%{"name" => "list-channel", "owner_id" => owner.id, "created_by_id" => owner.id})

    # no explicit channel_member created for owner; list should include owner
    members = Forum.list_channel_members(channel.id)
    assert Enum.any?(members, fn m -> Map.get(m, :user_id) == owner.id and Map.get(m, :role) == "owner" end)

    # create invite and verify it appears as invited entry
    {:ok, invite} = Forum.create_personal_invite(owner.id, invited.email, channel.id)
    members2 = Forum.list_channel_members(channel.id)
    assert Enum.any?(members2, fn m -> Map.get(m, :user_id) == invited.id and Map.get(m, :role) == "invited" end)
  end
end

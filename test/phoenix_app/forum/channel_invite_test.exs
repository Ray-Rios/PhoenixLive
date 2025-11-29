defmodule PhoenixApp.Forum.ChannelInviteTest do
  use ExUnit.Case, async: true

  alias PhoenixApp.Forum.ChannelInvite

  test "is_valid?/1 returns false for expired invites" do
    now = DateTime.utc_now()
    expired = %ChannelInvite{expires_at: DateTime.add(now, -3600)}

    refute ChannelInvite.is_valid?(expired)
  end

  test "is_valid?/1 returns false when uses >= max_uses" do
    invite = %ChannelInvite{uses: 5, max_uses: 5}

    refute ChannelInvite.is_valid?(invite)
  end

  test "is_valid?/1 returns true for open invites" do
    invite = %ChannelInvite{uses: 0, max_uses: nil, expires_at: nil, is_revoked: false}

    assert ChannelInvite.is_valid?(invite)
  end
end

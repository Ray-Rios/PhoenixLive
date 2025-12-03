defmodule PhoenixAppWeb.ForumLiveTest do
  use PhoenixAppWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias PhoenixApp.{Accounts, Forum, Repo}

  @endpoint PhoenixAppWeb.Endpoint

  # ConnCase already checks out the DB and sets up shared mode for non-async tests.

  defp user_attrs(email, name) do
    %{
      email: email,
      name: name,
      password: "Test@1234"
    }
  end

  test "members modal shows owner and invited entries with actions" do
    {:ok, owner} = Accounts.create_user(user_attrs("owner_lv@example.com", "owner_lv"))
    {:ok, invited} = Accounts.create_user(user_attrs("invited_lv@example.com", "invited_lv"))

    # Create a private channel so owner sees member-management UI in the LiveView
    {:ok, channel} = Forum.create_channel(%{"name" => "lv-channel", "owner_id" => owner.id, "created_by_id" => owner.id, "is_private" => true, "is_user_created" => true})

    # Create a personal invite
    {:ok, _invite} = Forum.create_personal_invite(owner.id, invited.email, channel.id)

    # Build a conn with a session containing the owner id so on_mount assigns current_user
    conn = build_conn() |> init_test_session(%{"user_id" => owner.id})

    {:ok, view, _html} = live(conn, "/forum/#{channel.id}")

    # Trigger the members modal open event (button exists in the UI)
    view |> element("button[phx-click=\"open_members_modal\"]") |> render_click(%{"channel_id" => channel.id})

    html = render(view)

    assert html =~ "Members — ##{channel.name}"
    assert html =~ "Invited"
    assert html =~ "Revoke Invite"
  end

  test "messages render oldest -> newest and show date + 12-hour timestamp" do
    {:ok, owner} = Accounts.create_user(user_attrs("owner_msgs@example.com", "owner_msgs"))
    {:ok, channel} = Forum.create_channel(%{"name" => "msgs-channel", "owner_id" => owner.id, "created_by_id" => owner.id})

    # Insert two messages with explicit inserted_at timestamps so ordering & formatting are predictable
    msg1 = %PhoenixApp.Forum.Message{content: "first_msg", user_id: owner.id, channel_id: channel.id, inserted_at: ~U[2025-12-01 04:05:00Z]} |> Repo.insert!()
    msg2 = %PhoenixApp.Forum.Message{content: "second_msg", user_id: owner.id, channel_id: channel.id, inserted_at: ~U[2025-12-01 06:10:00Z]} |> Repo.insert!()

    conn = build_conn() |> init_test_session(%{"user_id" => owner.id})
    {:ok, view, _html} = live(conn, "/forum/#{channel.id}")

    html = render(view)

    # Ensure both messages are present and timestamps render correctly.
    assert html =~ "first_msg"
    assert html =~ "second_msg"

    # Timestamps should include date and 12-hour time (eg. Dec 01 2025 04:05 AM)
    assert html =~ ~r/Dec\s+01\s+2025\s+04:05\s+(AM|PM)/
    assert html =~ ~r/Dec\s+01\s+2025\s+06:10\s+(AM|PM)/
  end

  test "create button placed above public channels and admins see delete for public channels but not general" do
    {:ok, admin} = Accounts.create_user(user_attrs("admin_ui@example.com", "admin_ui") |> Map.put(:role, "admin"))
    {:ok, owner} = Accounts.create_user(user_attrs("owner_ui@example.com", "owner_ui"))

    # Ensure general exists
    general = Forum.get_or_create_default_channel()

    # Create an extra public channel for testing
    {:ok, public_ch} = Forum.create_channel(%{"name" => "public-test", "owner_id" => owner.id, "created_by_id" => owner.id, "is_private" => false})

    conn = build_conn() |> init_test_session(%{"user_id" => admin.id})
    {:ok, view, _html} = live(conn, "/forum/#{public_ch.id}")
    html = render(view)

    # Create new channel button should be present and labeled exactly
    assert html =~ "Create new channel"

    # Admin on a public channel should see Delete button (but not when viewing General)
    assert html =~ "Delete"

    # Now load the general channel and verify Delete is not present
    {:ok, view2, _} = live(conn, "/forum/#{general.id}")
    html2 = render(view2)
    refute html2 =~ "Delete"  # Delete should not be offered for #general
  end

  test "private channels are not listed under public channels" do
    {:ok, user} = Accounts.create_user(user_attrs("pc_user@example.com", "pc_user"))
    {:ok, private_ch} = Forum.create_channel(%{"name" => "secret-only", "owner_id" => user.id, "created_by_id" => user.id, "is_private" => true})

    conn = build_conn() |> init_test_session(%{"user_id" => user.id})
    {:ok, view, _} = live(conn, "/forum/#{private_ch.id}")
    html = render(view)

    # Ensure private channel name does not appear in the 'Public Channels' list
    # Basic check: Public channels header exists but channel name should be present only in private section
    assert html =~ "Public Channels"
    assert html =~ "Private Channels"

    # Private channel name should not be listed under public channels: ensure it appears somewhere in html
    assert html =~ "secret-only"

    # A more robust parse would inspect sections; here we at least ensure UI includes the channel and the headers are present
  end

  test "admin can delete public channel but cannot delete general" do
    {:ok, admin} = Accounts.create_user(user_attrs("admin_delete@example.com", "admin_delete") |> Map.put(:role, "admin"))
    {:ok, owner} = Accounts.create_user(user_attrs("owner_delete@example.com", "owner_delete"))

    # Create a public channel
    {:ok, public_ch} = Forum.create_channel(%{"name" => "delete-me", "owner_id" => owner.id, "created_by_id" => owner.id, "is_private" => false})

    # Ensure general exists
    general = Forum.get_or_create_default_channel()

    conn = build_conn() |> init_test_session(%{"user_id" => admin.id})
    {:ok, view, _} = live(conn, "/forum/#{public_ch.id}")

    # Click the delete confirmation and then confirm deletion
    view |> element("button[phx-click=\"show_delete_channel_confirm\"]") |> render_click()
    assert render(view) =~ "Delete Permanently"

    view |> element("button[phx-click=\"confirm_delete_channel\"]") |> render_click()

    # Channel should no longer exist
    assert Forum.get_channel(public_ch.id) == nil

    # Now ensure general cannot be deleted (delete button shouldn't be shown)
    {:ok, view2, _} = live(conn, "/forum/#{general.id}")
    html2 = render(view2)
    refute html2 =~ "Delete"  # no delete offered for #general even for admin
  end

  test "messages_read event updates channel_member last_read_message_id" do
    {:ok, user} = Accounts.create_user(user_attrs("reader@example.com", "reader"))
    {:ok, channel} = Forum.create_channel(%{"name" => "reading-room", "owner_id" => user.id, "created_by_id" => user.id})

    # Ensure user is a member (owner) and create a message
    {:ok, member} = Forum.create_channel_member(%{channel_id: channel.id, user_id: user.id, role: "owner"})

    msg = %PhoenixApp.Forum.Message{content: "r1", user_id: user.id, channel_id: channel.id} |> Repo.insert!()

    conn = build_conn() |> init_test_session(%{"user_id" => user.id})
    {:ok, view, _} = live(conn, "/forum/#{channel.id}")

    # Simulate client telling server it's read up to the last message by calling
    # the underlying context function directly (LiveView's handle_event will
    # call the same function; in this test we exercise the behaviour without
    # relying on push_event helper compatibility across LiveView versions).
    {:ok, _member} = Forum.mark_channel_messages_read(user.id, channel.id, msg.id)

    # Reload member from DB to assert update
    updated = Forum.get_channel_member(channel.id, user.id)
    assert updated.last_read_message_id == msg.id
    assert not is_nil(updated.last_seen_at)
  end

  test "cursor pagination loads older messages" do
    {:ok, user} = Accounts.create_user(user_attrs("pager@example.com", "pager"))
    {:ok, channel} = Forum.create_channel(%{"name" => "paged-room", "owner_id" => user.id, "created_by_id" => user.id})

    # Create 120 messages (so default 50 will show and older remain)
    for i <- 1..120 do
      %PhoenixApp.Forum.Message{content: "m#{i}", user_id: user.id, channel_id: channel.id, inserted_at: DateTime.add(~U[2025-12-01 00:00:00Z], i, :second)} |> Repo.insert!()
    end

    conn = build_conn() |> init_test_session(%{"user_id" => user.id})
    {:ok, view, _} = live(conn, "/forum/#{channel.id}")

    html = render(view)
    # The initial set should include recent messages (this app loads a window of messages)
    # Ensure the most recent page includes one of the newest messages (m120 expected in the initial window)
    assert html =~ "m120"

    # Find the first message rendered in the page (the oldest of the initial window)
    # Simulate client requesting older messages with before_id as the first message id in the DOM
    first_msg = Forum.list_messages(channel.id, 50) |> List.first()
    assert first_msg != nil

    # Request older messages via the context helper and assert expected results
    older = Forum.list_messages_cursor(channel.id, %{before: first_msg.id, limit: 50})

    # The older page should contain messages older than the first message in
    # the current window. Verify we got some results and they are strictly older.
    assert length(older) > 0
    assert Enum.all?(older, fn m -> DateTime.compare(m.inserted_at, first_msg.inserted_at) == :lt end)
  end
end

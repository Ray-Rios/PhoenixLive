defmodule PhoenixAppWeb.ForumLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  alias PhoenixApp.{Accounts, Forum, Repo}

  @endpoint PhoenixAppWeb.Endpoint

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

  test "members modal shows owner and invited entries with actions" do
    {:ok, owner} = Accounts.create_user(user_attrs("owner_lv@example.com", "owner_lv"))
    {:ok, invited} = Accounts.create_user(user_attrs("invited_lv@example.com", "invited_lv"))

    {:ok, channel} = Forum.create_channel(%{"name" => "lv-channel", "owner_id" => owner.id, "created_by_id" => owner.id})

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
    assert html =~ "Make Owner"
  end
end

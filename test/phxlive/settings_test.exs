defmodule Phxlive.SettingsTest do
  use Phxlive.DataCase, async: true

  alias Phxlive.Settings

  # The test database is built from migrations, which used to leave a
  # cms_options table Settings couldn't use at all.
  test "options can be created, read, updated and deleted" do
    assert Settings.get_option("site_name", "fallback") == "fallback"

    # Several new names in a row: the old unique index on `key` broke the second.
    assert {:ok, _} = Settings.set_option("site_name", "PhxLive")
    assert {:ok, _} = Settings.set_option("posts_per_page", "10")
    assert {:ok, _} = Settings.set_option("comments_enabled", "true", false)

    assert Settings.get_option("site_name") == "PhxLive"
    assert {:ok, _} = Settings.set_option("site_name", "Renamed")
    assert Settings.get_option("site_name") == "Renamed"
    assert Enum.find(Settings.list_options(), &(&1.option_name == "comments_enabled")).autoload == "no"

    assert {:ok, _} = Settings.delete_option("posts_per_page")
    assert Settings.get_option("posts_per_page") == nil
  end

  test "the default user role setting works" do
    assert Settings.get_default_user_role() == "member"
    assert {:ok, _} = Settings.set_default_user_role("moderator")
    assert Settings.get_default_user_role() == "moderator"
    assert {:error, :invalid_role} = Settings.set_default_user_role("superuser")
  end
end

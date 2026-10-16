defmodule Phxlive.Plugins.State do
  @moduledoc "A plugin's activation, as last set on /admin/plugins. See `Phxlive.Plugins`."
  use Ecto.Schema

  @primary_key {:slug, :string, autogenerate: false}
  @foreign_key_type :binary_id
  schema "plugin_states" do
    field :active, :boolean
    belongs_to :changed_by, Phxlive.Accounts.User
    timestamps(type: :utc_datetime_usec)
  end
end

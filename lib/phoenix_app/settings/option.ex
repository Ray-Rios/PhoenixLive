defmodule PhoenixApp.Settings.Option do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "cms_options" do
    field :option_name, :string
    field :option_value, :string
    field :autoload, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(option, attrs) do
    option
    |> cast(attrs, [:option_name, :option_value, :autoload])
    |> validate_required([:option_name, :option_value])
    |> unique_constraint(:option_name)
  end
end
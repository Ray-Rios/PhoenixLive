defmodule PhoenixApp.EqemuGame.Account do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "eqemu_accounts" do
    field :eqemu_id, :integer
    field :name, :string
    field :charname, :string
    field :sharedplat, :integer, default: 0
    field :password, :string
    field :status, :integer, default: 0
    field :ls_id, :string
    field :lsaccount_id, :integer, default: 0
    field :gmspeed, :integer, default: 0
    field :revoked, :integer, default: 0
    field :karma, :integer, default: 0
    field :minilogin_ip, :string
    field :hideme, :integer, default: 0
    field :rulesflag, :integer, default: 0
    field :suspendeduntil, :utc_datetime
    field :time_creation, :integer, default: 0
    field :expansion, :integer, default: 8

    belongs_to :user, PhoenixApp.Accounts.User
    has_many :characters, PhoenixApp.EqemuGame.Character, foreign_key: :account_id, references: :eqemu_id

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :user_id, :eqemu_id, :name, :charname, :sharedplat, :password, :status,
      :ls_id, :lsaccount_id, :gmspeed, :revoked, :karma, :minilogin_ip,
      :hideme, :rulesflag, :suspendeduntil, :time_creation, :expansion
    ])
    |> validate_required([:user_id, :name, :eqemu_id])
    |> validate_length(:name, min: 3, max: 30)
    |> unique_constraint(:eqemu_id)
    |> unique_constraint(:name)
    |> unique_constraint(:user_id)
  end

  def create_changeset(account, attrs) do
    account
    |> changeset(attrs)
    |> put_change(:time_creation, System.system_time(:second))
  end
end
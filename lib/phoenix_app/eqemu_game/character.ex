defmodule PhoenixApp.EqemuGame.Character do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "eqemu_characters" do
    field :eqemu_id, :integer
    field :account_id, :integer
    field :name, :string
    field :level, :integer, default: 1
    field :race, :integer
    field :class, :integer
    field :gender, :integer, default: 0
    field :zone_id, :integer, default: 1
    field :zone_instance, :integer, default: 0
    field :x, :float, default: 0.0
    field :y, :float, default: 0.0
    field :z, :float, default: 0.0
    field :heading, :float, default: 0.0
    field :hp, :integer, default: 100
    field :mana, :integer, default: 0
    field :endurance, :integer, default: 100
    field :exp, :integer, default: 0
    field :aa_points_spent, :integer, default: 0
    field :aa_exp, :integer, default: 0
    field :platinum, :integer, default: 0
    field :gold, :integer, default: 0
    field :silver, :integer, default: 0
    field :copper, :integer, default: 0
    field :platinum_bank, :integer, default: 0
    field :gold_bank, :integer, default: 0
    field :silver_bank, :integer, default: 0
    field :copper_bank, :integer, default: 0
    field :platinum_cursor, :integer, default: 0
    field :gold_cursor, :integer, default: 0
    field :silver_cursor, :integer, default: 0
    field :copper_cursor, :integer, default: 0
    field :face, :integer, default: 1
    field :hair_color, :integer, default: 1
    field :hair_style, :integer, default: 1
    field :beard, :integer, default: 0
    field :beard_color, :integer, default: 1
    field :eye_color_1, :integer, default: 1
    field :eye_color_2, :integer, default: 1
    field :drakkin_heritage, :integer, default: 0
    field :drakkin_tattoo, :integer, default: 0
    field :drakkin_details, :integer, default: 0
    field :deity, :integer, default: 396
    field :birthday, :integer, default: 0
    field :last_login, :integer, default: 0
    field :time_played, :integer, default: 0
    field :pvp_status, :integer, default: 0
    field :level2, :integer, default: 0
    field :anon, :integer, default: 0
    field :gm, :integer, default: 0
    field :intoxication, :integer, default: 0
    field :exp_enabled, :integer, default: 1
    field :aa_points, :integer, default: 0
    field :group_leadership_exp, :integer, default: 0
    field :raid_leadership_exp, :integer, default: 0
    field :group_leadership_points, :integer, default: 0
    field :raid_leadership_points, :integer, default: 0
    field :mailkey, :string
    field :xtargets, :integer, default: 5
    field :firstlogon, :integer, default: 0
    field :e_aa_effects, :integer, default: 0
    field :e_percent_to_aa, :integer, default: 0
    field :e_expended_aa_spent, :integer, default: 0

    belongs_to :user, PhoenixApp.Accounts.User
    has_one :stats, PhoenixApp.EqemuGame.CharacterStats
    # has_many :inventory, PhoenixApp.EqemuGame.CharacterInventory  # Commented out until CharacterInventory schema is created

    timestamps()
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, [
      :user_id, :eqemu_id, :account_id, :name, :level, :race, :class, :gender,
      :zone_id, :zone_instance, :x, :y, :z, :heading, :hp, :mana, :endurance,
      :exp, :aa_points_spent, :aa_exp, :platinum, :gold, :silver, :copper,
      :platinum_bank, :gold_bank, :silver_bank, :copper_bank,
      :platinum_cursor, :gold_cursor, :silver_cursor, :copper_cursor,
      :face, :hair_color, :hair_style, :beard, :beard_color, :eye_color_1, 
      :eye_color_2, :drakkin_heritage, :drakkin_tattoo, :drakkin_details, 
      :deity, :birthday, :last_login, :time_played, :pvp_status, :level2, 
      :anon, :gm, :intoxication, :exp_enabled, :aa_points,
      :group_leadership_exp, :raid_leadership_exp, :group_leadership_points,
      :raid_leadership_points, :mailkey, :xtargets, :firstlogon,
      :e_aa_effects, :e_percent_to_aa, :e_expended_aa_spent
    ])
    |> validate_required([:user_id, :account_id, :name, :race, :class])
    |> validate_length(:name, min: 3, max: 64)
    |> validate_number(:level, greater_than: 0, less_than_or_equal_to: 65)
    |> validate_number(:race, greater_than: 0)
    |> validate_number(:class, greater_than: 0)
    |> validate_inclusion(:gender, [0, 1, 2])
    |> unique_constraint(:name)
    |> unique_constraint(:eqemu_id)
  end

  def race_name(%__MODULE__{race: race_id}) do
    PhoenixApp.EqemuGame.get_race_name(race_id)
  end

  def class_name(%__MODULE__{class: class_id}) do
    PhoenixApp.EqemuGame.get_class_name(class_id)
  end

  def deity_name(%__MODULE__{deity: deity_id}) do
    PhoenixApp.EqemuGame.get_deity_name(deity_id)
  end

  def total_money(%__MODULE__{} = character) do
    character.platinum * 1000 + character.gold * 100 + character.silver * 10 + character.copper
  end

  def is_online?(%__MODULE__{last_login: last_login}) when is_nil(last_login), do: false
  def is_online?(%__MODULE__{last_login: last_login}) do
    DateTime.diff(DateTime.utc_now(), last_login, :minute) < 5
  end

  def experience_to_next_level(%__MODULE__{level: level, exp: exp}) do
    next_level_exp = PhoenixApp.EqemuGame.calculate_experience_for_level(level + 1)
    _current_level_exp = PhoenixApp.EqemuGame.calculate_experience_for_level(level)
    next_level_exp - exp
  end

  def experience_percentage(%__MODULE__{level: level, exp: exp}) do
    next_level_exp = PhoenixApp.EqemuGame.calculate_experience_for_level(level + 1)
    current_level_exp = PhoenixApp.EqemuGame.calculate_experience_for_level(level)
    
    if next_level_exp == current_level_exp do
      100.0
    else
      ((exp - current_level_exp) / (next_level_exp - current_level_exp)) * 100.0
    end
  end
end
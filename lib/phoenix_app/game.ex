defmodule PhoenixApp.Game do
  import Ecto.Query

  alias PhoenixApp.Repo
  alias PhoenixApp.Game.{Character, Zone, Spell, CharacterSpell}

  @max_characters_per_user 16
  @default_zone_slug "lobby"
  @valid_model_extensions [".glb", ".gltf", ".fbx"]
  @preferred_model_extensions [".glb", ".gltf"]
  @default_max_models 48
  @supported_models_manifest "supported_models.txt"
  @builtin_models [
    %{label: "Builtin/Explorer", model_path: "builtin://explorer"},
    %{label: "Builtin/Sentinel", model_path: "builtin://sentinel"},
    %{label: "Builtin/Runner", model_path: "builtin://runner"}
  ]

  def list_user_characters(user_id) when is_binary(user_id) do
    Character
    |> where([character], character.user_id == ^user_id)
    |> order_by([character], asc: character.inserted_at)
    |> preload(:last_zone)
    |> Repo.all()
  end

  def create_character(user_id, attrs) when is_binary(user_id) and is_map(attrs) do
    with :ok <- ensure_character_cap(user_id),
         {:ok, zone} <- get_default_zone(),
         {:ok, model_path} <- validate_model_path(Map.get(attrs, "model_path") || Map.get(attrs, :model_path)) do
      attrs
      |> Map.new(fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), value}
        pair -> pair
      end)
      |> Map.put("model_path", model_path)
      |> Map.put("approved_at", DateTime.utc_now() |> DateTime.truncate(:second))
      |> Map.put("last_zone_id", zone.id)
      |> Map.put("last_x", zone.spawn_x)
      |> Map.put("last_y", zone.spawn_y)
      |> Map.put("last_z", zone.spawn_z)
      |> Map.put("last_heading", zone.spawn_heading)
      |> Map.put("user_id", user_id)
      |> then(&Character.changeset(%Character{}, &1))
      |> Repo.insert()
      |> case do
        {:ok, character} = result ->
          grant_starter_spells(character.id)
          result

        error ->
          error
      end
    end
  end

  def get_character_for_user(user_id, character_id)
      when is_binary(user_id) and is_binary(character_id) do
    Character
    |> where([character], character.id == ^character_id and character.user_id == ^user_id)
    |> preload(:last_zone)
    |> Repo.one()
  end

  def delete_character_for_user(user_id, character_id)
      when is_binary(user_id) and is_binary(character_id) do
    case get_character_for_user(user_id, character_id) do
      nil ->
        {:error, :not_found}

      character ->
        Repo.delete(character)
    end
  end

  def character_login_payload(user_id, character_id)
      when is_binary(user_id) and is_binary(character_id) do
    case get_character_for_user(user_id, character_id) do
      nil ->
        {:error, :not_found}

      character ->
        spells = list_character_spells(character.id)

        {:ok,
         %{
           user_id: character.user_id,
           character_id: character.id,
           name: character.name,
           character_type: character.character_type,
           model_path: character.model_path,
           hp: character.hp,
           max_hp: character.max_hp,
           mp: character.mp,
           max_mp: character.max_mp,
           pvp_flagged: character.pvp_flagged,
           spells: Enum.map(spells, fn s ->
             %{
               slug: s.slug,
               name: s.name,
               mp_cost: s.mp_cost,
               base_damage: s.base_damage,
               range: s.range,
               recast_ms: s.recast_ms,
               projectile_type: s.projectile_type
             }
           end),
           zone: %{
             id: character.last_zone_id,
             name: character.last_zone && character.last_zone.name,
             slug: character.last_zone && character.last_zone.slug
           },
           position: %{
             x: character.last_x,
             y: character.last_y,
             z: character.last_z,
             heading: character.last_heading
           }
         }}
    end
  end

  def update_character_spawn(user_id, character_id, attrs)
      when is_binary(user_id) and is_binary(character_id) and is_map(attrs) do
    case get_character_for_user(user_id, character_id) do
      nil ->
        {:error, :not_found}

      character ->
        character
        |> Character.changeset(%{
          last_zone_id: Map.get(attrs, "last_zone_id") || Map.get(attrs, :last_zone_id) || character.last_zone_id,
          last_x: Map.get(attrs, "last_x") || Map.get(attrs, :last_x) || character.last_x,
          last_y: Map.get(attrs, "last_y") || Map.get(attrs, :last_y) || character.last_y,
          last_z: Map.get(attrs, "last_z") || Map.get(attrs, :last_z) || character.last_z,
          last_heading: Map.get(attrs, "last_heading") || Map.get(attrs, :last_heading) || character.last_heading,
          approved_at: character.approved_at,
          name: character.name,
          character_type: character.character_type,
          model_path: character.model_path,
          user_id: character.user_id
        })
        |> Repo.update()
    end
  end

  def list_models do
    models =
      models_roots()
    |> Enum.flat_map(fn models_root ->
      models_root
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.filter(&valid_model_file?/1)
      |> Enum.map(fn abs_path ->
        relative_path =
          abs_path
          |> Path.relative_to(models_root)
          |> String.replace("\\", "/")

        %{
          label: relative_path,
          relative_path: relative_path,
          model_path: "/models/" <> relative_path,
          extension: Path.extname(relative_path) |> String.downcase()
        }
      end)
    end)
    |> Enum.uniq_by(& &1.model_path)

    curated_models =
      models
      |> filter_supported_models()
      |> prioritize_model_extensions()
      |> Enum.sort_by(& &1.label)
      |> Enum.take(max_models())
      |> Enum.map(&Map.drop(&1, [:relative_path, :extension]))

    if curated_models == [] and builtin_models_enabled?(), do: @builtin_models, else: curated_models
  end

  defp models_roots do
    cwd_root = Path.expand("priv/static/models", File.cwd!())
    app_dir_root = Application.app_dir(:phoenix_app, "priv/static/models")
    app_root = "/app/priv/static/models"

    release_roots = Path.wildcard("/app/lib/phoenix_app-*/priv/static/models")

    [app_dir_root, cwd_root, app_root | release_roots]
    |> Enum.uniq()
    |> Enum.filter(&File.dir?/1)
  end

  defp ensure_character_cap(user_id) do
    count =
      Character
      |> where([character], character.user_id == ^user_id)
      |> select([character], count(character.id))
      |> Repo.one()

    if count >= @max_characters_per_user do
      {:error, :character_limit_reached}
    else
      :ok
    end
  end

  defp get_default_zone do
    case Repo.get_by(Zone, slug: @default_zone_slug) do
      nil -> {:error, :default_zone_missing}
      zone -> {:ok, zone}
    end
  end

  defp validate_model_path(path) when is_binary(path) do
    available_paths = list_models() |> Enum.map(& &1.model_path)

    if path in available_paths do
      {:ok, path}
    else
      {:error, :invalid_model_path}
    end
  end

  defp validate_model_path(_), do: {:error, :invalid_model_path}

  defp valid_model_file?(file_path) do
    extension = file_path |> Path.extname() |> String.downcase()
    extension in @valid_model_extensions
  end

  defp max_models do
    case System.get_env("MAX_CHARACTER_MODELS") do
      nil -> @default_max_models
      value ->
        case Integer.parse(value) do
          {parsed, _} when parsed > 0 -> parsed
          _ -> @default_max_models
        end
    end
  end

  defp filter_supported_models(models) do
    supported = load_supported_models_manifest()

    if MapSet.size(supported) == 0 do
      models
      |> Enum.reject(&hashed_variant?/1)
    else
      Enum.filter(models, &MapSet.member?(supported, &1.relative_path))
    end
  end

  defp prioritize_model_extensions(models) do
    {preferred, fallback} =
      Enum.split_with(models, fn model ->
        model.extension in @preferred_model_extensions
      end)

    preferred ++ fallback
  end

  defp builtin_models_enabled? do
    System.get_env("ENABLE_BUILTIN_MODELS") in ["1", "true", "TRUE", "yes", "YES"]
  end

  defp hashed_variant?(model) do
    String.match?(model.relative_path, ~r/-[0-9a-f]{12,}\.(fbx|gltf|glb)$/i)
  end

  defp load_supported_models_manifest do
    models_roots()
    |> Enum.map(&Path.join(&1, @supported_models_manifest))
    |> Enum.filter(&File.exists?/1)
    |> Enum.take(1)
    |> case do
      [manifest_path] ->
        manifest_path
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
        |> MapSet.new()

      [] ->
        MapSet.new()
    end
  end

  # ── Spell helpers ────────────────────────────────────────────────────────────

  def get_spell_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Spell, slug: slug)
  end

  def list_character_spells(character_id) when is_binary(character_id) do
    CharacterSpell
    |> where([cs], cs.character_id == ^character_id)
    |> preload(:spell)
    |> Repo.all()
    |> Enum.map(& &1.spell)
  end

  @doc """
  Grants the starter spells to a freshly created character.
  Called immediately after character creation.
  """
  def grant_starter_spells(character_id) when is_binary(character_id) do
    case get_spell_by_slug("throw_stone") do
      nil ->
        :ok

      spell ->
        %CharacterSpell{}
        |> CharacterSpell.changeset(%{
          character_id: character_id,
          spell_id: spell.id,
          unlocked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.insert(on_conflict: :nothing)

        :ok
    end
  end

  # ── HP / MP helpers ──────────────────────────────────────────────────────────

  def get_character_stats(character_id) when is_binary(character_id) do
    case Repo.get(Character, character_id) do
      nil -> {:error, :not_found}
      ch  -> {:ok, %{hp: ch.hp, max_hp: ch.max_hp, mp: ch.mp, max_mp: ch.max_mp}}
    end
  end

  def update_character_hp_mp(character_id, hp, mp)
      when is_binary(character_id) and is_integer(hp) and is_integer(mp) do
    case Repo.get(Character, character_id) do
      nil ->
        {:error, :not_found}

      ch ->
        ch
        |> Ecto.Changeset.change(%{
          hp: max(0, min(hp, ch.max_hp)),
          mp: max(0, min(mp, ch.max_mp))
        })
        |> Repo.update()
    end
  end

  def respawn_character(character_id) when is_binary(character_id) do
    case Repo.get(Character, character_id) |> Repo.preload(:last_zone) do
      nil ->
        {:error, :not_found}

      ch ->
        zone = ch.last_zone
        ch
        |> Ecto.Changeset.change(%{
          hp: ch.max_hp,
          mp: ch.max_mp,
          last_x: (zone && zone.spawn_x) || 0.0,
          last_y: (zone && zone.spawn_y) || 0.0,
          last_z: (zone && zone.spawn_z) || 0.0,
          last_heading: (zone && zone.spawn_heading) || 0.0
        })
        |> Repo.update()
    end
  end

  # ── Combat: Throw Stone ──────────────────────────────────────────────────────

  @throw_stone_hit_chance 0.85

  @doc """
  Server-authoritative Throw Stone combat.

  Returns one of:
    {:ok, %{hit: bool, damage: 0|1, caster_mp: int, target_hp: int}}
    {:error, atom}
  """
  def cast_throw_stone(caster_id, target_id, caster_pos, target_pos)
      when is_binary(caster_id) and is_binary(target_id) do
    with {:ok, spell}   <- fetch_spell("throw_stone"),
         {:ok, caster}  <- fetch_character(caster_id),
         {:ok, target}  <- fetch_character(target_id),
         :ok            <- check_pvp(caster, target),
         :ok            <- check_mp(caster, spell.mp_cost),
         :ok            <- check_range(caster_pos, target_pos, spell.range) do

      hit    = :rand.uniform() <= @throw_stone_hit_chance
      damage = if hit, do: spell.base_damage, else: 0

      new_caster_mp = caster.mp - spell.mp_cost
      new_target_hp = max(0, target.hp - damage)

      {:ok, _} = update_character_hp_mp(caster_id, caster.hp, new_caster_mp)
      {:ok, _} = update_character_hp_mp(target_id, new_target_hp, target.mp)

      died = new_target_hp == 0 and target.hp > 0

      # Respawn DB update happens here; position correction is pushed by the
      # target's own LiveView process when it receives :zone_spell_result.
      spawn_coords =
        if died do
          case respawn_character(target_id) do
            {:ok, ch} -> %{x: ch.last_x, y: ch.last_y, z: ch.last_z, heading: ch.last_heading}
            _         -> nil
          end
        end

      {:ok,
       %{
         hit: hit,
         damage: damage,
         caster_mp: new_caster_mp,
         caster_max_mp: caster.max_mp,
         target_hp: new_target_hp,
         target_max_hp: target.max_hp,
         target_died: died,
         spawn_coords: spawn_coords,
         target_id: target_id,
         caster_id: caster_id
       }}
    end
  end

  defp fetch_spell(slug) do
    case get_spell_by_slug(slug) do
      nil   -> {:error, :spell_not_found}
      spell -> {:ok, spell}
    end
  end

  defp fetch_character(id) do
    case Repo.get(Character, id) do
      nil -> {:error, :character_not_found}
      ch  -> {:ok, ch}
    end
  end

  defp check_pvp(caster, target) do
    if caster.pvp_flagged and target.pvp_flagged do
      :ok
    else
      {:error, :pvp_not_flagged}
    end
  end

  defp check_mp(character, cost) do
    if character.mp >= cost, do: :ok, else: {:error, :insufficient_mp}
  end

  defp check_range(%{x: cx, z: cz}, %{x: tx, z: tz}, max_range) do
    dist = :math.sqrt(:math.pow(tx - cx, 2) + :math.pow(tz - cz, 2))
    if dist <= max_range, do: :ok, else: {:error, :out_of_range}
  end

  defp check_range(_, _, _), do: {:error, :invalid_position}
end
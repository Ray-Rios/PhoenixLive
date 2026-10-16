defmodule Phxlive.Games.HoloSimSpec do
  @moduledoc """
  Turns the options a player picks at the Holo-sim door into the world spec the
  instance builds from.

  ## Decided by Ray, 2026-10-08 - see PROJECT.md §13, fortieth pass

    * A sim is built from OPTIONS CHOSEN AT CREATION, one list for solar systems
      and one for single planets. No presets.
    * Options are FIXED for the life of the sim. Changing them means deleting the
      sim. Only name and visibility are editable afterwards.
    * Solar systems keep the station. A single planet is an empty grid until
      height maps exist to choose from.
    * Solar systems restart on their seeded orbits when reloaded; what players
      built is what persists.

  ## Why the hub generates the spec, not the client

  `holo_sims.spec` is fed to `UCosmosWorldBuilder::BuildFromJson` inside an
  instance. Accepting a client-authored spec would let any player choose the
  planet count (a CPU bomb), any asset path, and any field the builder reads. A
  closed set of options, validated here, makes the spec something the hub
  vouches for. The client sends `options`; any `spec` it sends is ignored.

  ## Shape of the output

  Always an `FSolarSystemSpec`, field names exactly as the C++ struct, so one
  parser reads every sim. A single planet is a system with no planet field, no
  sun and no station; what makes it a planet is in `Metadata` - the struct's
  own free-form map "for game-specific data the schema does not model" - which
  is also where the chosen options are recorded so the door and the website can
  show them without a second column.

  `Metadata` is `TMap<FString, FString>` in C++, so EVERY value written there is
  a string. A number or boolean would fail the parse on the instance, at the
  worst possible moment.

  Pure: no database, no config, no JSON library. Exercisable from bare `elixir`.
  """

  alias Phxlive.Games.HoloSimSpec.Base

  @spec_version "1"

  # --- Solar system ---------------------------------------------------------

  @planet_counts [10, 25, 50, 81, 120]
  @default_planet_count 81

  # Radius ranges in cm, the same units as the base template. "mixed" is the
  # shared world's own range (build_cosmos.py PLANET_R).
  @planet_sizes %{
    "small" => {28_125.0, 112_500.0},
    "mixed" => {28_125.0, 375_000.0},
    "large" => {150_000.0, 375_000.0}
  }

  @dice ~w(D4 D6 D8 D12 D20 Sphere)
  @tetrominoes ~w(I O T S Z J L)
  @shapes @dice ++ @tetrominoes

  @atmospheres %{"none" => 0.0, "some" => 0.35, "all" => 1.0}

  # The tint that carries patrols in the shared world. Patrols attach to planets
  # whose atmosphere has this name, so they need atmospheres to exist at all.
  @patrol_atmosphere "Red"

  # --- Single planet ----------------------------------------------------------

  @grid_sizes_m [500, 2000, 8000]
  @gravities %{"0.5" => 490.0, "1" => 980.0, "1.5" => 1470.0}
  @skies ~w(vacuum planetary)

  # Linear RGB, written into Metadata as "R,G,B" so the instance does not need a
  # second copy of this table to know what "moss" means.
  @grid_colors %{
    "slate" => {0.18, 0.20, 0.24},
    "sand" => {0.76, 0.66, 0.48},
    "ice" => {0.70, 0.85, 0.95},
    "moss" => {0.25, 0.42, 0.22},
    "rust" => {0.55, 0.25, 0.12},
    "violet" => {0.40, 0.25, 0.62}
  }

  @max_seed 2_147_483_647

  @doc "Everything the door needs to draw the creation form."
  def catalog do
    %{
      "system" => %{
        "planet_count" => %{"choices" => @planet_counts, "default" => @default_planet_count},
        "planet_size" => %{"choices" => ~w(small mixed large), "default" => "mixed"},
        "shapes" => %{"dice" => @dice, "tetrominoes" => @tetrominoes, "default" => @shapes},
        "atmospheres" => %{"choices" => ~w(none some all), "default" => "all"},
        "hostile_patrols" => %{"default" => false},
        "seed" => %{"min" => 1, "max" => @max_seed, "default" => "random"}
      },
      "planet" => %{
        "grid_size_m" => %{"choices" => @grid_sizes_m, "default" => 2000},
        "gravity" => %{"choices" => ~w(0.5 1 1.5), "default" => "1"},
        "sky" => %{"choices" => @skies, "default" => "vacuum"},
        "grid_color" => %{"choices" => Map.keys(@grid_colors) |> Enum.sort(), "default" => "slate"}
      }
    }
  end

  @doc """
  Build a spec.

  `{:ok, spec}` or `{:error, message}` with a message fit to show a player.
  Unknown option keys are ignored; known ones must be valid - a bad value is an
  error, never silently replaced by a default, because the player would then get
  a different world from the one they asked for and could never change it.
  """
  def build(kind, options, sim_id, name)

  def build("system", options, sim_id, name) when is_map(options) do
    with {:ok, count} <- pick(options, "planet_count", @default_planet_count, &valid_count/1),
         {:ok, size} <- pick(options, "planet_size", "mixed", &Map.has_key?(@planet_sizes, &1)),
         {:ok, shapes} <- shapes(options),
         {:ok, atmo} <- pick(options, "atmospheres", "all", &Map.has_key?(@atmospheres, &1)),
         {:ok, patrols} <- pick(options, "hostile_patrols", false, &is_boolean/1),
         :ok <- patrols_need_atmospheres(patrols, atmo),
         {:ok, seed} <- seed(options) do
      {min_r, max_r} = Map.fetch!(@planet_sizes, size)
      base = Base.system()

      field =
        base["PlanetField"]
        |> Map.put("Count", count)
        |> Map.put("MinRadius", min_r)
        |> Map.put("MaxRadius", max_r)
        |> Map.put("ShapeWeights", Enum.map(shapes, &shape_weight/1))
        |> Map.put("AtmosphereChance", Map.fetch!(@atmospheres, atmo))
        |> Map.put("EnemyPatrolAtmosphere", if(patrols, do: @patrol_atmosphere, else: "None"))

      spec =
        base
        |> Map.put("PlanetField", field)
        |> Map.put("StarField", Map.put(base["StarField"], "Seed", derived_seed(seed)))
        |> identity(sim_id, name, seed)
        |> Map.put("Metadata", %{
          "holo_sim_kind" => "system",
          "spec_version" => @spec_version,
          "planet_count" => Integer.to_string(count),
          "planet_size" => size,
          "shapes" => Enum.join(shapes, ","),
          "atmospheres" => atmo,
          "hostile_patrols" => to_string(patrols),
          "seed" => Integer.to_string(seed)
        })

      {:ok, spec}
    end
  end

  def build("planet", options, sim_id, name) when is_map(options) do
    with {:ok, size} <- pick(options, "grid_size_m", 2000, &(&1 in @grid_sizes_m)),
         {:ok, gravity} <- pick(options, "gravity", "1", &Map.has_key?(@gravities, &1)),
         {:ok, sky} <- pick(options, "sky", "vacuum", &(&1 in @skies)),
         {:ok, color} <- pick(options, "grid_color", "slate", &Map.has_key?(@grid_colors, &1)) do
      base = Base.system()
      {r, g, b} = Map.fetch!(@grid_colors, color)

      # A system with nothing in it. The instance sees holo_sim_kind=planet and
      # builds the grid from Metadata instead of a planet field. Arena radius is
      # kept because the spec validator (and the builder) require a positive one.
      spec =
        base
        |> Map.put("PlanetField", Map.put(base["PlanetField"], "Count", 0))
        |> Map.put("Arena", Map.put(base["Arena"], "bSpawnArenaManager", false))
        |> Map.put("Station", Map.put(base["Station"], "bEnabled", false))
        |> Map.put("FixedBodies", [])
        |> identity(sim_id, name, 0)
        |> Map.put("Metadata", %{
          "holo_sim_kind" => "planet",
          "spec_version" => @spec_version,
          "grid_size_m" => Integer.to_string(size),
          "gravity_g" => gravity,
          "surface_gravity" => float_string(Map.fetch!(@gravities, gravity)),
          "sky" => sky,
          "grid_color" => color,
          "grid_color_rgb" => Enum.map_join([r, g, b], ",", &float_string/1)
        })

      {:ok, spec}
    end
  end

  def build(kind, _options, _sim_id, _name) when kind in ["system", "planet"],
    do: {:error, "options must be an object"}

  def build(_kind, _options, _sim_id, _name),
    do: {:error, "Choose a solar system or a single planet."}

  @doc """
  The options a spec was built from, for display. Read back out of Metadata, so
  it is exactly what was recorded - not a re-derivation that could drift.
  """
  def options(%{"Metadata" => %{"holo_sim_kind" => _} = meta}) do
    meta
    |> Map.drop(["spec_version", "surface_gravity", "grid_color_rgb"])
  end

  def options(_), do: %{}

  # -------------------------------------------------------------------------

  defp identity(spec, sim_id, name, seed) do
    spec
    |> Map.put("SystemId", to_string(sim_id || ""))
    |> Map.put("DisplayName", name || "")
    |> Map.put("Seed", seed)
  end

  # Returns the default when the key is absent or null; otherwise the value must
  # pass the check. Integers may arrive as strings from a form-encoded client.
  defp pick(options, key, default, valid?) do
    case Map.get(options, key) do
      nil ->
        {:ok, default}

      value ->
        value = coerce(value, default)

        if valid?.(value),
          do: {:ok, value},
          else: {:error, "#{humanize(key)}: #{inspect(Map.get(options, key))} is not one of the choices."}
    end
  end

  defp coerce(value, default) when is_integer(default) and is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp coerce(value, default) when is_boolean(default) and value in ["true", "false"],
    do: value == "true"

  # Gravity choices are strings ("0.5"); a JSON client may send the number.
  defp coerce(value, default) when is_binary(default) and is_number(value) do
    if value == trunc(value), do: Integer.to_string(trunc(value)), else: to_string(value)
  end

  defp coerce(value, _), do: value

  defp valid_count(n), do: n in @planet_counts

  # "A selection box for each type, then split them evenly among the chosen
  # options." Order follows the catalog, not the request, so the same choice
  # always produces the same spec - and the same seed the same system.
  defp shapes(options) do
    case Map.get(options, "shapes") do
      nil ->
        {:ok, @shapes}

      list when is_list(list) ->
        chosen = Enum.filter(@shapes, &(&1 in list))
        unknown = Enum.reject(list, &(&1 in @shapes))

        cond do
          unknown != [] -> {:error, "Unknown planet shape(s): #{Enum.join(unknown, ", ")}."}
          chosen == [] -> {:error, "Pick at least one planet shape."}
          true -> {:ok, chosen}
        end

      _ ->
        {:error, "shapes must be a list."}
    end
  end

  # Equal weights ARE the even split: the builder draws from the bag by weight.
  # A tetromino entry sets TetrominoShape and leaves DieShape at Sphere, which is
  # the either/or rule APoolPlanet enforces (see build_cosmos.py).
  defp shape_weight(shape) when shape in @tetrominoes,
    do: %{"DieShape" => "Sphere", "TetrominoShape" => shape, "Weight" => 1000}

  defp shape_weight(shape),
    do: %{"DieShape" => shape, "TetrominoShape" => "None", "Weight" => 1000}

  defp patrols_need_atmospheres(true, "none"),
    do: {:error, "Hostile patrols live around planets with atmospheres. Turn atmospheres on, or patrols off."}

  defp patrols_need_atmospheres(_, _), do: :ok

  defp seed(options) do
    case Map.get(options, "seed") do
      v when v in [nil, "", "random"] ->
        {:ok, :rand.uniform(@max_seed)}

      v ->
        case coerce(v, 0) do
          n when is_integer(n) and n >= 1 and n <= @max_seed -> {:ok, n}
          _ -> {:error, "Seed must be a whole number from 1 to #{@max_seed}."}
        end
    end
  end

  # The star field gets its own stream so the sky differs between systems too,
  # but is still fixed by the one seed a player can share.
  defp derived_seed(seed), do: rem(seed * 7919 + 99, @max_seed) + 1

  defp float_string(f), do: :erlang.float_to_binary(f / 1, [:compact, decimals: 4])

  defp humanize(key), do: key |> String.replace("_", " ") |> String.capitalize()
end

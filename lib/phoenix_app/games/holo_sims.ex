defmodule PhoenixApp.Games.HoloSims do
  @moduledoc """
  Holo-sim CRUD, access control, slots and persisted state.

  Separate from `PhoenixApp.Games` because this is a large enough surface to
  stand on its own, and because the access rules want to live in one place
  rather than scattered across controller actions.

  ACCESS IS DECIDED HERE, NOWHERE ELSE. `can_access?/2` is the single rule, and
  both the player API and the server-key endpoint the instance server calls go
  through it. Two implementations of "may this user enter" would eventually
  disagree, and the disagreement would be a security hole rather than a bug.
  """

  import Ecto.Query, warn: false

  alias PhoenixApp.GamesRepo
  alias PhoenixApp.Games.{HoloSim, HoloSimMember, HoloSimSlot, HoloSimState}

  @default_slots 10

  # ---------------------------------------------------------------------
  # Access
  # ---------------------------------------------------------------------

  @doc """
  May this user enter this sim?

    * `public`   — anyone
    * `unlisted` — INVITE REQUIRED, and hidden from public listings
    * `invite`   — invite required, may still appear in listings
    * `private`  — owner only

  Note `unlisted` requires an invitation, exactly like `invite`. The difference
  between them is discoverability, not access: an `invite` sim can be surfaced
  in a listing so people know to ask, an `unlisted` one cannot. Neither is
  enterable by a stranger who happens to have the id.

  Locked sims stay enterable: locking freezes EDITS pending review, and kicking
  people out of a world they are standing in is a heavier action than an admin
  usually intends.
  """
  def can_access?(%HoloSim{} = sim, user_id) when is_binary(user_id) do
    cond do
      sim.owner_user_id == user_id -> true
      sim.visibility == "public" -> true
      sim.visibility in ["invite", "unlisted"] -> member?(sim.id, user_id)
      true -> false
    end
  end

  def can_access?(_, _), do: false

  @doc "Only the owner may edit, and only while the sim is unlocked."
  def can_edit?(%HoloSim{} = sim, user_id) do
    sim.owner_user_id == user_id and not sim.is_locked
  end

  def can_edit?(_, _), do: false

  def member?(sim_id, user_id) do
    HoloSimMember
    |> where([m], m.holo_sim_id == ^sim_id and m.user_id == ^user_id)
    |> GamesRepo.exists?()
  end

  # ---------------------------------------------------------------------
  # Reads
  # ---------------------------------------------------------------------

  def get_sim(id), do: GamesRepo.get(HoloSim, id)

  def get_sim_for_user(id, user_id) do
    case get_sim(id) do
      nil -> {:error, :not_found}
      sim -> if can_access?(sim, user_id), do: {:ok, sim}, else: {:error, :forbidden}
    end
  end

  @doc "Sims this user owns."
  def list_owned(game_id, user_id) do
    HoloSim
    |> where([s], s.game_id == ^game_id and s.owner_user_id == ^user_id)
    |> order_by([s], desc: s.last_launched_at, asc: s.name)
    |> GamesRepo.all()
  end

  @doc """
  Sims shared with this user by invitation.

  Excludes ones they own — an owner inviting themselves would otherwise appear
  in both lists.
  """
  def list_shared(game_id, user_id) do
    HoloSim
    |> join(:inner, [s], m in HoloSimMember, on: m.holo_sim_id == s.id)
    |> where([s, m], s.game_id == ^game_id and m.user_id == ^user_id)
    |> where([s, _m], s.owner_user_id != ^user_id)
    |> order_by([s, _m], asc: s.name)
    |> GamesRepo.all()
  end

  @doc """
  Publicly listed sims.

  `unlisted` is deliberately excluded: it means reachable by id, not
  discoverable. Requires `is_published` so a player can build a public sim
  without it appearing half-finished.
  """
  def list_public(game_id, opts \\ []) do
    limit_n = Keyword.get(opts, :limit, 50)

    HoloSim
    |> where([s], s.game_id == ^game_id and s.visibility == "public" and s.is_published == true)
    |> order_by([s], desc: s.launch_count, asc: s.name)
    |> limit(^limit_n)
    |> GamesRepo.all()
  end

  # ---------------------------------------------------------------------
  # Slots
  # ---------------------------------------------------------------------

  def slots_for(game_id, user_id) do
    case GamesRepo.get_by(HoloSimSlot, game_id: game_id, user_id: user_id) do
      nil -> %HoloSimSlot{game_id: game_id, user_id: user_id, granted_slots: @default_slots}
      slot -> slot
    end
  end

  def slot_usage(game_id, user_id) do
    used =
      HoloSim
      |> where([s], s.game_id == ^game_id and s.owner_user_id == ^user_id)
      |> GamesRepo.aggregate(:count, :id)

    %{used: used, total: HoloSimSlot.total(slots_for(game_id, user_id))}
  end

  @doc "Grant extra slots. Called by the commerce module after a purchase."
  def add_purchased_slots(game_id, user_id, count) when is_integer(count) and count > 0 do
    slot = slots_for(game_id, user_id)

    attrs = %{
      "game_id" => game_id,
      "user_id" => user_id,
      "granted_slots" => slot.granted_slots,
      "purchased_slots" => slot.purchased_slots + count
    }

    case slot.id do
      nil -> %HoloSimSlot{} |> HoloSimSlot.changeset(attrs) |> GamesRepo.insert()
      _ -> slot |> HoloSimSlot.changeset(attrs) |> GamesRepo.update()
    end
  end

  # ---------------------------------------------------------------------
  # Writes
  # ---------------------------------------------------------------------

  @doc """
  Create a sim, enforcing the per-account slot limit.

  Slots are per account: each player owns up to `granted + purchased` sims of
  their own. Nobody shares a pool.

  ATOMIC. The count and the insert happen inside one transaction holding a
  `FOR UPDATE` lock on that account's slot row, so two simultaneous creates from
  the same account serialise instead of both passing the check. The lock is on
  one row belonging to one player — it never blocks anybody else's create.

  A slot row is written first if none exists, purely so there is something to
  lock; `on_conflict: :nothing` makes that safe when two requests race to be the
  one that creates it.
  """
  def create_sim(game_id, owner_user_id, attrs) do
    result =
      GamesRepo.transaction(fn ->
        slot = lock_slot_row(game_id, owner_user_id)

        used =
          HoloSim
          |> where([s], s.game_id == ^game_id and s.owner_user_id == ^owner_user_id)
          |> GamesRepo.aggregate(:count, :id)

        total = slot.granted_slots + slot.purchased_slots

        if used >= total do
          GamesRepo.rollback(
            {:slot_limit,
             "You are using #{used} of #{total} Holo-sim slots. Delete one or buy more."}
          )
        else
          insert =
            %HoloSim{}
            |> HoloSim.changeset(
              attrs
              |> Map.put("game_id", game_id)
              |> Map.put("owner_user_id", owner_user_id)
            )
            |> GamesRepo.insert()

          case insert do
            {:ok, sim} -> sim
            {:error, changeset} -> GamesRepo.rollback(changeset)
          end
        end
      end)

    # Unwrap the transaction's shape back into what callers already expect.
    case result do
      {:ok, %HoloSim{} = sim} -> {:ok, sim}
      {:error, {:slot_limit, message}} -> {:error, :slot_limit, message}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      {:error, other} -> {:error, other}
    end
  end

  # Guarantees a slot row exists, then locks it for the rest of the transaction.
  # Must be called inside a transaction or the lock is meaningless.
  defp lock_slot_row(game_id, user_id) do
    GamesRepo.insert(
      %HoloSimSlot{
        game_id: game_id,
        user_id: user_id,
        granted_slots: @default_slots,
        purchased_slots: 0
      },
      on_conflict: :nothing,
      conflict_target: [:game_id, :user_id]
    )

    HoloSimSlot
    |> where([s], s.game_id == ^game_id and s.user_id == ^user_id)
    |> lock("FOR UPDATE")
    |> GamesRepo.one!()
  end

  def update_sim(%HoloSim{} = sim, attrs) do
    sim |> HoloSim.owner_changeset(attrs) |> GamesRepo.update()
  end

  def delete_sim(%HoloSim{} = sim), do: GamesRepo.delete(sim)

  @doc "Bump launch bookkeeping. Called when an instance is successfully handed out."
  def record_launch(%HoloSim{} = sim) do
    sim
    |> Ecto.Changeset.change(%{
      last_launched_at: DateTime.utc_now() |> DateTime.truncate(:second),
      launch_count: sim.launch_count + 1
    })
    |> GamesRepo.update()
  end

  # ---------------------------------------------------------------------
  # Members
  # ---------------------------------------------------------------------

  def list_members(sim_id) do
    HoloSimMember
    |> where([m], m.holo_sim_id == ^sim_id)
    |> order_by([m], asc: m.invited_at)
    |> GamesRepo.all()
  end

  @doc """
  Invite a user.

  Refuses to invite the owner: they already have access, and a self-invite would
  make the sim appear in their "Shared with me" list as well as "Mine".
  """
  def invite_member(%HoloSim{} = sim, user_id, invited_by_user_id, role \\ "viewer") do
    if user_id == sim.owner_user_id do
      {:error, :already_owner, "The owner already has access."}
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %HoloSimMember{}
      |> HoloSimMember.changeset(%{
        "holo_sim_id" => sim.id,
        "user_id" => user_id,
        "role" => role,
        "invited_by_user_id" => invited_by_user_id,
        "invited_at" => now
      })
      |> GamesRepo.insert()
    end
  end

  def remove_member(sim_id, user_id) do
    case GamesRepo.get_by(HoloSimMember, holo_sim_id: sim_id, user_id: user_id) do
      nil -> {:error, :not_found}
      member -> GamesRepo.delete(member)
    end
  end

  def accept_invite(sim_id, user_id) do
    case GamesRepo.get_by(HoloSimMember, holo_sim_id: sim_id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      member ->
        member
        |> HoloSimMember.changeset(%{
          "accepted_at" => DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> GamesRepo.update()
    end
  end

  # ---------------------------------------------------------------------
  # Persisted state
  # ---------------------------------------------------------------------

  @doc "The sim's saved state, or nil if it has never been saved."
  def get_state(sim_id) do
    GamesRepo.get_by(HoloSimState, holo_sim_id: sim_id)
  end

  @doc """
  May this user cause a save?

  The owner always may. Anyone else only if the owner opted in via
  `visitors_can_build`. A shared world has no undo, so collaboration is
  opt-in rather than opt-out.
  """
  def can_persist?(%HoloSim{} = sim, user_id) do
    sim.owner_user_id == user_id or sim.visitors_can_build
  end

  def can_persist?(_, _), do: false

  @doc """
  Upsert the sim's state.

  One row per sim: a shared instance holds one world in memory, so it can only
  have one saved state. `last_saved_by_user_id` records who wrote it, which is
  what makes moderation possible once visitors can build.

  Refuses the write outright when the saver may not persist, rather than
  quietly discarding it — a server that thinks it saved and did not is worse
  than one told no.
  """
  def save_state(%HoloSim{} = sim, saved_by_user_id, state) when is_map(state) do
    if can_persist?(sim, saved_by_user_id) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs = %{
        "holo_sim_id" => sim.id,
        "state" => state,
        "saved_at" => now,
        "last_saved_by_user_id" => saved_by_user_id
      }

      case get_state(sim.id) do
        nil -> %HoloSimState{} |> HoloSimState.changeset(attrs) |> GamesRepo.insert()
        existing -> existing |> HoloSimState.changeset(attrs) |> GamesRepo.update()
      end
    else
      {:error, :cannot_persist,
       "Only the owner can save changes to this Holo-sim."}
    end
  end

  @doc "Discard the save, so the next launch rebuilds from the spec."
  def reset_state(sim_id) do
    case get_state(sim_id) do
      nil -> {:ok, :nothing_to_reset}
      existing -> GamesRepo.delete(existing)
    end
  end

  # ---------------------------------------------------------------------
  # Launch rate limiting
  # ---------------------------------------------------------------------

  @launch_window_seconds 60
  @launches_per_window 5

  @doc """
  May this user start another instance right now?

  There is no cap on concurrent instances — occupancy already bounds cost, since
  an empty pod shuts down and a busy one is busy because people are in it. The
  only abuse left is cycling launches to churn pods, and a rate limit is the
  right shape for that: no legitimate player opens six doors a minute.

  Counts sims this user launched recently rather than instances currently up,
  so leaving a popular sim running never counts against them.
  """
  def launch_allowed?(game_id, user_id) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@launch_window_seconds, :second)
      |> DateTime.truncate(:second)

    recent =
      PhoenixApp.Games.GameServer
      |> where([s], s.game_id == ^game_id and s.launched_by_user_id == ^user_id)
      |> where([s], s.inserted_at >= ^cutoff)
      |> GamesRepo.aggregate(:count, :id)

    if recent < @launches_per_window do
      :ok
    else
      {:error, :rate_limited,
       "Too many Holo-sims started in the last minute. Wait a moment and try again."}
    end
  end

  def default_slots, do: @default_slots
end

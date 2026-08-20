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

  DELEGATES TO `SimAccess`, WHICH ASKS THE FORUM CHANNEL. A sim's access control
  list is its channel's membership; there is no separate Holo-sim guest list to
  keep in step. The rule lives in `SimAccess` because it spans two databases,
  not because there are two rules.

  Sims created before the link have no channel and fall back to their own
  `visibility` field. That path is frozen - new sims always have a channel.

  Locked sims stay enterable: locking freezes EDITS pending review, and kicking
  people out of a world they are standing in is a heavier action than an admin
  usually intends.
  """
  defdelegate can_access?(sim, user_id), to: PhoenixApp.Games.SimAccess

  @doc "Only the owner may edit, and only while the sim is unlocked."
  def can_edit?(%HoloSim{} = sim, user_id) do
    sim.owner_user_id == user_id and not sim.is_locked
  end

  def can_edit?(_, _), do: false

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
  Sims this user can enter but does not own — the channels they belong to.

  Excludes ones they own, so the two lists the client renders side by side do
  not both contain the same sim.

  Note this is no longer "shared by invitation". Membership of the channel IS
  the invitation, so a sim appears here the moment its owner adds the player to
  the forum channel, whether that happened in game or on the website.
  """
  def list_shared(game_id, user_id) do
    game_id
    |> PhoenixApp.Games.SimAccess.list_accessible(user_id)
    |> Enum.reject(&(&1.owner_user_id == user_id))
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
  # Slots — SUPERSEDED BY users.channel_allowance, KEPT FOR ITS DATA
  # ---------------------------------------------------------------------
  #
  # This was the Holo-sim limit: 10 granted, purchasable. It no longer binds.
  # A sim requires a channel, one channel holds at most one sim, and the channel
  # allowance (5) is smaller - so the slot counter can only ever agree, or be
  # wrong in the direction that blocks a player who has paid for more channels
  # than they have slots.
  #
  # NOT DELETED because `holo_sim_slots` holds real rows, including any
  # purchased_slots someone was granted. Deleting the code first and the table
  # later loses the record of what people were given.
  #
  # `create_sim/3` below still enforces it and is now only reachable from tests
  # and from any caller that has not moved to `create_for_channel/3`. When the
  # table is empty of purchases, delete this section, the schema, and the table
  # together.

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

  @doc """
  Create a channel and its Holo-sim together. The in-game "make a new sim" path.

  TWO DATABASES, TWO COMMITS, NO TRANSACTION. The channel lands in the main
  database and the sim in the games database, so this cannot be atomic. The
  order and the failure handling are therefore the design:

    1. Create the channel first. It carries the allowance check, so an over-limit
       player is stopped before anything exists.
    2. Create the sim pointing at it.
    3. If step 2 fails, DELETE THE CHANNEL AGAIN.

  Step 3 is a compensating action, not a rollback, and it can itself fail - a
  crash between 1 and 3 leaves a channel with no sim. That state is harmless
  and, importantly, not novel: it is identical to a channel created on the
  website whose owner has not built a sim yet, which the system already renders.
  Choosing that as the failure mode is why the channel is created first.

  The reverse order would fail worse: a sim with no channel has no access
  control list at all, and `SimAccess.can_access?/2` refuses it outright, so it
  would be a world its own creator could not enter.

  ## The slot limit does not apply here

  `create_sim/3` enforces `holo_sim_slots` (10, purchasable). This path does not,
  because a sim now requires a channel and the channel allowance (5) is the
  smaller number - so slots could never bind, except in the one case where they
  bind WRONGLY: a player who buys their way past 10 channels would be stopped by
  a slot counter nobody sold them. One limit, on the thing the shop actually
  sells.
  """
  def create_for_channel(game_id, %{id: user_id} = user, attrs) do
    channel_attrs = %{
      "name" => Map.get(attrs, "name", "New Holo-sim"),
      "description" => Map.get(attrs, "description"),
      # No icon: the game has no picker and no upload. A default is used until
      # the owner changes it on the website, which is the agreed behaviour -
      # hence nil rather than a placeholder path that would have to be
      # recognised and ignored later.
      "icon_path" => nil,
      "is_private" => Map.get(attrs, "visibility", "private") != "public",
      "channel_type" => "text"
    }

    with {:ok, channel} <- PhoenixApp.Forum.create_user_channel(user, channel_attrs) do
      sim_attrs =
        attrs
        |> Map.put("game_id", game_id)
        |> Map.put("owner_user_id", user_id)
        |> Map.put("channel_id", channel.id)

      case %HoloSim{} |> HoloSim.changeset(sim_attrs) |> GamesRepo.insert() do
        {:ok, sim} ->
          {:ok, sim, channel}

        {:error, changeset} ->
          # Compensate. Best effort: if this fails the player has a channel with
          # no sim, and can build one from the door next time.
          PhoenixApp.Forum.delete_channel(channel)
          {:error, changeset}
      end
    end
  end

  @doc """
  Attach a sim to a channel that already exists — the website-first path.

  Every forum channel on phxlive predates this feature and has no sim. The owner
  walks up to the door in game, picks their channel, and builds the world then.
  No allowance is consumed: the channel was already counted when it was created.
  """
  def create_for_existing_channel(game_id, user_id, channel_id, attrs) do
    cond do
      not is_binary(channel_id) ->
        {:error, :no_channel, "Pick a channel for this Holo-sim."}

      not owns_channel?(channel_id, user_id) ->
        # Same message for "not yours" and "does not exist" - a stranger probing
        # ids should not learn which channels are real.
        {:error, :forbidden, "You can only build a Holo-sim in a channel you own."}

      not is_nil(PhoenixApp.Games.SimAccess.sim_for_channel(channel_id)) ->
        {:error, :already_exists, "That channel already has a Holo-sim."}

      true ->
        attrs =
          attrs
          |> Map.put("game_id", game_id)
          |> Map.put("owner_user_id", user_id)
          |> Map.put("channel_id", channel_id)

        %HoloSim{} |> HoloSim.changeset(attrs) |> GamesRepo.insert()
    end
  end

  defp owns_channel?(channel_id, user_id) do
    case PhoenixApp.Repo.get(PhoenixApp.Forum.Channel, channel_id) do
      nil -> false
      channel -> channel.owner_id == user_id
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

  @doc """
  Update a sim, keeping its channel's publicity in step.

  VISIBILITY IS STORED TWICE AND MUST NOT DIVERGE. `sim.visibility` decides
  whether the sim appears in public listings; `channel.is_public` decides
  whether a stranger may walk in. Set one without the other and you get the
  dangerous combination: an owner marks their sim private, the listing hides it,
  and the channel is still public so anyone with the id can enter. The sim looks
  private and is not.

  Syncing here rather than deriving one from the other because both are read on
  hot paths in different databases, and a derived value would mean a cross-
  database read to answer "is this listed".
  """
  def update_sim(%HoloSim{} = sim, attrs) do
    case sim |> HoloSim.owner_changeset(attrs) |> GamesRepo.update() do
      {:ok, updated} ->
        sync_channel_publicity(updated)
        {:ok, updated}

      error ->
        error
    end
  end

  defp sync_channel_publicity(%HoloSim{channel_id: channel_id, visibility: visibility})
       when is_binary(channel_id) do
    should_be_public = visibility == "public"

    case PhoenixApp.Repo.get(PhoenixApp.Forum.Channel, channel_id) do
      nil ->
        :ok

      channel ->
        if channel.is_public != should_be_public do
          # Not via Forum.update_channel/2: that broadcasts and audits a user
          # action, and this is a consequence of one that was already audited.
          channel
          |> Ecto.Changeset.change(%{
            is_public: should_be_public,
            is_private: not should_be_public
          })
          |> PhoenixApp.Repo.update()
        end

        :ok
    end
  end

  defp sync_channel_publicity(_), do: :ok

  @doc """
  Delete the sim. THE CHANNEL SURVIVES.

  Deliberately asymmetric with `SimAccess.channel_deleted/1`, which does delete
  the sim. A channel is a conversation that can exist without a world - that is
  the normal state of every channel on the website - so deleting a world should
  not delete the history of people talking about it. A world without a channel
  has no access control list and cannot exist.

  The freed channel becomes buildable again, so the owner can start a different
  world in the same community without spending another channel slot.
  """
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

  # MEMBERSHIP IS CHANNEL MEMBERSHIP.
  #
  # These functions keep their names and shapes because the game already calls
  # them, but they now read and write `channel_members` in the main database.
  # Inviting someone to a Holo-sim IS adding them to its forum channel - they
  # get the world and the conversation in one action, which is the behaviour
  # that was asked for and also the only way one ACL stays one ACL.
  #
  # `holo_sim_members` is still read for sims that predate the link, and is
  # never written to again.

  @doc "Everyone with access, as channel members. Empty for a legacy sim."
  def list_members(sim_id) do
    case get_sim(sim_id) do
      %HoloSim{channel_id: channel_id} when is_binary(channel_id) ->
        PhoenixApp.Forum.list_channel_members(channel_id)

      %HoloSim{} ->
        HoloSimMember
        |> where([m], m.holo_sim_id == ^sim_id)
        |> order_by([m], asc: m.invited_at)
        |> GamesRepo.all()

      nil ->
        []
    end
  end

  @doc """
  Give a user access, by adding them to the sim's channel.

  Refuses the owner: they already have access, and adding them would put their
  own sim in their "shared with me" list as well as "mine".
  """
  def invite_member(sim, user_id, invited_by_user_id, role \\ "member")

  def invite_member(%HoloSim{owner_user_id: owner}, owner, _by, _role) do
    {:error, :already_owner, "The owner already has access."}
  end

  def invite_member(%HoloSim{channel_id: nil}, _user_id, _by, _role) do
    {:error, :no_channel,
     "This Holo-sim predates channel linking and cannot take new members. Recreate it to share it."}
  end

  def invite_member(%HoloSim{channel_id: channel_id}, user_id, _invited_by_user_id, role) do
    # "viewer" is the old Holo-sim vocabulary; channels speak owner/moderator/
    # member. Anything unrecognised becomes a plain member rather than an error,
    # so an older client calling with the old role name still works.
    channel_role = if role in ["owner", "moderator", "member"], do: role, else: "member"

    case PhoenixApp.Forum.get_channel_member(channel_id, user_id) do
      nil ->
        PhoenixApp.Forum.create_channel_member(%{
          "channel_id" => channel_id,
          "user_id" => user_id,
          "role" => channel_role
        })

      existing ->
        # Already there. Un-ban rather than refuse: "invite" is the owner saying
        # yes, and it should override an earlier no.
        PhoenixApp.Forum.update_channel_member(existing, %{
          "is_banned" => false,
          "role" => channel_role
        })
    end
  end

  @doc """
  Take access away, and remove them from the running world if they are in it.

  The kick is the part that matters. Removing the membership alone stops the
  next join and does nothing about the person currently standing in the world.
  """
  def remove_member(sim_id, user_id) do
    case get_sim(sim_id) do
      %HoloSim{channel_id: channel_id} = sim when is_binary(channel_id) ->
        if sim.owner_user_id == user_id do
          {:error, :cannot_remove_owner}
        else
          # Forum.remove_channel_member/2 queues the kick itself. Calling
          # revoke_access here as well would queue a second one for the same
          # player - harmless, but it would show up twice in the audit log and
          # read like the first one failed.
          PhoenixApp.Forum.remove_channel_member(channel_id, user_id)
        end

      %HoloSim{} ->
        case GamesRepo.get_by(HoloSimMember, holo_sim_id: sim_id, user_id: user_id) do
          nil -> {:error, :not_found}
          member -> GamesRepo.delete(member)
        end

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Acknowledge an invitation.

  A no-op for channel-backed sims: channel membership grants access
  immediately, so there is nothing to accept. Kept so older clients that call
  it still get a success rather than a 404 they cannot act on.
  """
  def accept_invite(sim_id, user_id) do
    case get_sim(sim_id) do
      %HoloSim{channel_id: channel_id} when is_binary(channel_id) ->
        if PhoenixApp.Games.SimAccess.member?(channel_id, user_id) do
          {:ok, :already_active}
        else
          {:error, :not_found}
        end

      %HoloSim{} ->
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

      nil ->
        {:error, :not_found}
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
  `visitors_can_build`, or if they moderate the channel. A shared world has no
  undo, so collaboration is opt-in rather than opt-out.
  """
  defdelegate can_persist?(sim, user_id), to: PhoenixApp.Games.SimAccess, as: :can_build?

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

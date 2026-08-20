defmodule PhoenixApp.Games.SimAccess do
  @moduledoc """
  Who may enter a Holo-sim, and what happens when that answer changes.

  THE FORUM CHANNEL IS THE ACCESS CONTROL LIST. There is no separate Holo-sim
  membership to maintain, invite against, or keep in step. If you are in the
  channel you are in the sim; if you are removed from the channel you are
  removed from the sim, including out of a world you are currently standing in.

  This module exists because that rule spans two databases. `chat_channels` and
  `channel_members` are in the main repo; `holo_sims` and `game_servers` are in
  the games repo. Nothing can join them, so the join happens here, once, rather
  than in each caller.

  ## Why not mirror the membership into the games database

  A mirror would keep player joins single-database and would survive the main
  database being down. It was rejected because a mirror can be stale, and a
  stale ACL fails in exactly one direction: someone whose access was revoked
  still has it. Every sync bug becomes a security bug, and the failure is
  silent - nobody reports being able to get in.

  Reading the truth every time costs one indexed query per join. Player joins
  are rare (a person walks through a door), and the cost is paid in the one
  place where being wrong is worst.

  ## Legacy sims

  A sim with a nil `channel_id` predates the link and falls back to its own
  `visibility` field and `holo_sim_members` rows. That path is frozen: no new
  sim can be created without a channel. It exists so that data written before
  this change keeps working, and it can be deleted once no such rows remain.
  """

  import Ecto.Query, warn: false

  alias PhoenixApp.{Repo, GamesRepo}
  alias PhoenixApp.Forum.{Channel, ChannelMember}
  alias PhoenixApp.Games.{HoloSim, HoloSimMember, GameServer}

  # Channel roles that mean "no", regardless of a row existing.
  @denied_roles ~w(banned)

  # ---------------------------------------------------------------------
  # Reading access
  # ---------------------------------------------------------------------

  @doc """
  May this user enter this sim?

  The owner always may - including when they are not a member of their own
  channel, which is the normal state for a channel created in game where no
  `channel_members` row is written for the creator.
  """
  def can_access?(sim, user_id)

  def can_access?(%HoloSim{owner_user_id: owner}, owner) when is_binary(owner), do: true

  def can_access?(%HoloSim{channel_id: nil} = sim, user_id) when is_binary(user_id) do
    legacy_can_access?(sim, user_id)
  end

  def can_access?(%HoloSim{channel_id: channel_id}, user_id) when is_binary(user_id) do
    case Repo.get(Channel, channel_id) do
      # The channel was deleted and the sim outlived it. Refuse rather than fall
      # back to the sim's own visibility: an orphaned sim has no ACL at all, and
      # "no ACL" must never resolve to "public". See `channel_deleted/1` for the
      # path that is supposed to prevent this state existing.
      nil -> false
      channel -> channel_grants_access?(channel, user_id)
    end
  end

  def can_access?(_, _), do: false

  defp channel_grants_access?(%Channel{} = channel, user_id) do
    cond do
      channel.owner_id == user_id -> true
      banned?(channel.id, user_id) -> false
      channel.is_public -> true
      true -> member?(channel.id, user_id)
    end
  end

  @doc """
  A banned member is refused even in a public channel.

  Checked before the public shortcut for that reason: banning someone from a
  public channel has to mean something, or moderation only works on private
  ones.
  """
  def banned?(channel_id, user_id) do
    ChannelMember
    |> where([m], m.channel_id == ^channel_id and m.user_id == ^user_id)
    |> where([m], m.is_banned == true or m.role in ^@denied_roles)
    |> Repo.exists?()
  end

  def member?(channel_id, user_id) do
    ChannelMember
    |> where([m], m.channel_id == ^channel_id and m.user_id == ^user_id)
    |> where([m], m.is_banned == false)
    |> where([m], m.role not in ^@denied_roles)
    |> Repo.exists?()
  end

  @doc """
  May this user leave a permanent mark on the world?

  Owner always. Otherwise the owner must have opted in via `visitors_can_build`,
  and channel moderators are treated as trusted regardless - someone empowered
  to delete messages is not a person the owner is trying to keep from moving a
  crate.
  """
  def can_build?(%HoloSim{owner_user_id: owner}, owner) when is_binary(owner), do: true

  def can_build?(%HoloSim{} = sim, user_id) when is_binary(user_id) do
    cond do
      not can_access?(sim, user_id) -> false
      sim.visitors_can_build -> true
      is_nil(sim.channel_id) -> false
      true -> role_in_channel(sim.channel_id, user_id) in ["owner", "moderator"]
    end
  end

  def can_build?(_, _), do: false

  def role_in_channel(channel_id, user_id) do
    ChannelMember
    |> where([m], m.channel_id == ^channel_id and m.user_id == ^user_id)
    |> select([m], m.role)
    |> Repo.one()
  end

  # The pre-link rules, kept verbatim so old sims behave exactly as they did.
  defp legacy_can_access?(%HoloSim{} = sim, user_id) do
    cond do
      sim.visibility == "public" -> true
      sim.visibility in ["invite", "unlisted"] -> legacy_member?(sim.id, user_id)
      true -> false
    end
  end

  defp legacy_member?(sim_id, user_id) do
    HoloSimMember
    |> where([m], m.holo_sim_id == ^sim_id and m.user_id == ^user_id)
    |> GamesRepo.exists?()
  end

  # ---------------------------------------------------------------------
  # Listing
  # ---------------------------------------------------------------------

  @doc """
  Every sim this user may enter, owned or otherwise.

  Two queries against two databases, joined in memory: collect the channels the
  user owns or belongs to, then fetch the sims linked to them. There is no way
  to express this as one query, and pretending otherwise by looping sims and
  checking each would be a query per sim.
  """
  def list_accessible(game_id, user_id) when is_binary(user_id) do
    channel_ids = accessible_channel_ids(user_id)

    HoloSim
    |> where([s], s.game_id == ^game_id)
    |> where([s], s.owner_user_id == ^user_id or s.channel_id in ^channel_ids)
    |> order_by([s], desc: s.last_launched_at, asc: s.name)
    |> GamesRepo.all()
  end

  def list_accessible(_, _), do: []

  defp accessible_channel_ids(user_id) do
    owned =
      Channel
      |> where([c], c.owner_id == ^user_id)
      |> select([c], c.id)
      |> Repo.all()

    joined =
      ChannelMember
      |> where([m], m.user_id == ^user_id and m.is_banned == false)
      |> where([m], m.role not in ^@denied_roles)
      |> select([m], m.channel_id)
      |> Repo.all()

    # Public channels are deliberately NOT included. A public channel means
    # anyone MAY enter its sim; it does not mean the sim belongs on every
    # player's personal list. Discovery is a separate, browsable listing.
    Enum.uniq(owned ++ joined)
  end

  @doc """
  Which of these channel ids already have a sim, as a MapSet.

  One query for a list of channels rather than one per channel - the door shows
  the owner every channel they have, and that list grows with what they buy.
  """
  def channels_with_sims(channel_ids) when is_list(channel_ids) do
    HoloSim
    |> where([s], s.channel_id in ^channel_ids)
    |> select([s], s.channel_id)
    |> GamesRepo.all()
    |> MapSet.new()
  end

  @doc "The sim attached to a channel, if its owner has built one."
  def sim_for_channel(channel_id) when is_binary(channel_id) do
    GamesRepo.get_by(HoloSim, channel_id: channel_id)
  end

  def sim_for_channel(_), do: nil

  # ---------------------------------------------------------------------
  # Revocation
  # ---------------------------------------------------------------------

  @doc """
  Access was taken away. Get them out of the world too.

  Called when a member is removed from a channel or banned. Being removed from
  the channel already stops the NEXT join; this handles the person currently
  standing in the world, who would otherwise keep playing indefinitely because
  nothing re-checks access after the join.

  Best effort by design. If no instance is running, or the player is not in it,
  there is nothing to do and that is a success. The command is queued and
  delivered on the instance's next heartbeat - a second or two - and
  `take_pending_commands/1` is at-most-once, so a kick that misses its window is
  dropped rather than fired at whoever occupies that slot later.
  """
  def revoke_access(channel_id, user_id) when is_binary(channel_id) and is_binary(user_id) do
    case sim_for_channel(channel_id) do
      nil ->
        {:ok, :no_sim}

      %HoloSim{} = sim ->
        # The owner cannot be locked out of their own world by a membership
        # change - they are not in channel_members to begin with.
        if sim.owner_user_id == user_id do
          {:ok, :owner_exempt}
        else
          kick_from_running_instance(sim, user_id)
        end
    end
  end

  def revoke_access(_, _), do: {:ok, :no_sim}

  defp kick_from_running_instance(%HoloSim{} = sim, user_id) do
    case running_instance(sim) do
      nil ->
        {:ok, :not_running}

      server ->
        if in_roster?(server, user_id) do
          PhoenixApp.Games.queue_server_command(
            server.id,
            "kick",
            %{"user_id" => user_id, "reason" => "Access to this Holo-sim was removed."},
            nil
          )

          {:ok, :kick_queued}
        else
          {:ok, :not_present}
        end
    end
  end

  defp running_instance(%HoloSim{} = sim) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-PhoenixApp.Games.server_stale_after_seconds(), :second)
      |> DateTime.truncate(:second)

    GameServer
    |> where([s], s.holo_sim_id == ^sim.id)
    |> where([s], s.last_heartbeat_at >= ^cutoff)
    |> limit(1)
    |> GamesRepo.one()
  end

  # Read the roster we already collect from heartbeats rather than asking the
  # instance. Costs nothing, and avoids queueing a kick at a server that has
  # never heard of this player.
  defp in_roster?(%GameServer{roster: roster}, user_id) when is_map(roster) do
    roster
    |> Map.get("players", [])
    |> Enum.any?(fn
      %{"user_id" => ^user_id} -> true
      _ -> false
    end)
  end

  defp in_roster?(_, _), do: false

  @doc """
  A channel was deleted. Its sim has no ACL any more, so it cannot survive.

  Deleting the sim is the honest outcome: the sim's existence was predicated on
  the channel, `can_access?/2` refuses an orphan outright, and leaving one
  behind would be a world nobody can enter sitting against the owner's channel
  allowance forever.

  Returns the deleted sim so the caller can tell the owner what went with it.
  """
  def channel_deleted(channel_id) when is_binary(channel_id) do
    case sim_for_channel(channel_id) do
      nil ->
        {:ok, :no_sim}

      %HoloSim{} = sim ->
        # Shut the instance down first. Deleting the row while people are inside
        # leaves a pod serving a world with no database record - it would keep
        # running until its idle timer expired, and its saves would fail.
        case running_instance(sim) do
          nil ->
            :ok

          server ->
            PhoenixApp.Games.queue_server_command(
              server.id,
              "shutdown",
              %{"reason" => "The channel this Holo-sim belonged to was deleted."},
              nil
            )
        end

        GamesRepo.delete(sim)
        {:ok, sim}
    end
  end

  def channel_deleted(_), do: {:ok, :no_sim}
end

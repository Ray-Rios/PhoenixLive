defmodule Mix.Tasks.Rss.DevUsers do
  @shortdoc "Create pre-verified accounts for testing RaysSpaceSim from the UE editor"

  @moduledoc """
  Seeds the accounts the game client auto-logs into during development.

      mix rss.dev_users
      mix rss.dev_users --name Trebek --clients 3
      mix rss.dev_users --email trebek@rayspacesim.dev --password "hunter2hunter2"

  ## Why this exists

  `Accounts.authenticate_user_secure/3` refuses a login while `email_verified_at`
  is nil. Registering from the game client returns a token immediately, so the
  FIRST session works and every session after it fails — a confusing enough
  failure that it is worth removing rather than documenting. This task creates
  the accounts with verification already applied.

  ## Why more than one account

  Two PIE clients logged into the same account are not two players in any way
  worth testing: they share a character, they race each other's saves, and the
  bugs you actually want to catch — someone else's character appearing, an ACL
  refusing the wrong person — cannot happen at all. So client 1 gets `Trebek`
  and clients 2..N get `Trebek_C2`, `Trebek_C3`, and so on. The UE side derives
  the same names from the PIE instance index, so they line up without
  configuration.

  ## Options

    * `--name`     — display name of the primary account. Default `Trebek`.
                     Also the username: it must be unique across the hub.
    * `--email`    — primary email. Default `<name>@rayspacesim.dev`, lowercased.
                     Extra clients use plus-addressing off this one.
    * `--password` — default `DevPass123!`. The registration changeset demands 8+
                     characters with upper, lower, digit and symbol, so a
                     friendlier default like "devpassword" is silently rejected.
    * `--clients`  — how many accounts. Default 2, enough for one server and two
                     players.
    * `--slug`     — game slug to ensure exists. Default `rays-space-sim`, which
                     is `UPhxAccountSettings::GameSlug`'s default. If you change
                     one, change the other; the hub 404s on a mismatch rather
                     than guessing, and it reads as a broken build.

  Idempotent. An account that already exists is verified and left otherwise
  alone — in particular its PASSWORD IS NOT RESET, because silently changing the
  credentials of an account you already had is a bad way to find out this task
  matched something you did not mean it to.
  """

  use Mix.Task

  alias PhoenixApp.{Accounts, Games, Repo}

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    # This creates verified accounts with a published password. Running it
    # against production would be handing out keys.
    if Mix.env() == :prod do
      Mix.raise("rss.dev_users refuses to run in :prod. These are shared-password accounts.")
    end

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          name: :string,
          email: :string,
          password: :string,
          clients: :integer,
          slug: :string
        ]
      )

    name = opts[:name] || "Trebek"
    password = opts[:password] || "DevPass123!"
    clients = opts[:clients] || 2
    slug = opts[:slug] || "rays-space-sim"
    base_email = opts[:email] || "#{String.downcase(name)}@rayspacesim.dev"

    Mix.shell().info("Seeding #{clients} dev account(s) for '#{name}'.\n")

    users = Enum.map(1..clients, &ensure_user(&1, name, base_email, password))

    ensure_game(slug)

    Mix.shell().info("""

    Done. Password for all of them: #{password}

    In Unreal, set Project Settings > Plugins > Phx Account > Developer:
      Dev Auto Login   : true
      Dev Email        : #{base_email}
      Dev Password     : #{password}
      Dev Display Name : #{name}

    The client derives client 2+ from the primary email by plus-addressing, so
    those four values cover every PIE client.
    """)

    Enum.each(users, fn {email, user_name, status} ->
      Mix.shell().info("  #{String.pad_trailing(user_name, 14)} #{String.pad_trailing(email, 40)} #{status}")
    end)
  end

  # Client 1 is the primary account; 2+ hang off it with plus-addressing, which
  # every mail system treats as the same mailbox and every unique index treats
  # as a different address. Exactly the property wanted: one inbox, N accounts.
  defp ensure_user(1, name, base_email, password), do: upsert(base_email, name, password)

  defp ensure_user(index, name, base_email, password) do
    [local, domain] = String.split(base_email, "@", parts: 2)
    upsert("#{local}+c#{index}@#{domain}", "#{name}_C#{index}", password)
  end

  defp upsert(email, name, password) do
    case Accounts.get_user_by_email(email) do
      nil ->
        # Bypassing register_user/2 on purpose: it rate-limits, sends mail, and
        # returns an unverified user. None of that is wanted here, and the mail
        # send in particular fails noisily on a machine with no SMTP.
        case Accounts.create_user(%{
               "email" => email,
               "name" => name,
               "password" => password,
               "password_confirmation" => password
             }) do
          {:ok, user} ->
            verify!(user)
            {email, name, "created"}

          {:error, changeset} ->
            Mix.shell().error("  Could not create #{email}: #{inspect(changeset.errors)}")
            {email, name, "FAILED"}
        end

      user ->
        # Password deliberately untouched. See the moduledoc.
        verify!(user)
        {email, user.name, "existed, verified"}
    end
  end

  defp verify!(user) do
    if is_nil(user.email_verified_at) do
      {:ok, _} = Accounts.verify_user_email_direct(user)
    end

    :ok
  end

  # The client 404s on an unknown slug rather than guessing, so a missing games
  # row looks like a broken build. Cheap to rule out here.
  defp ensure_game(slug) do
    case Games.get_game_by_slug(slug) do
      nil ->
        case Games.create_game(%{name: "RaysSpaceSim", slug: slug}) do
          {:ok, _} -> Mix.shell().info("\nCreated games row '#{slug}'.")
          {:error, cs} -> Mix.shell().error("\nCould not create game '#{slug}': #{inspect(cs.errors)}")
        end

      _ ->
        Mix.shell().info("\nGames row '#{slug}' already present.")
    end
  end

  # Silences an "unused alias" warning while keeping the dependency visible:
  # this task only makes sense with a started repo.
  @doc false
  def repo, do: Repo
end

defmodule PhoenixAppWeb.Schema do
  use Absinthe.Schema
  alias PhoenixApp.{Accounts, Game, Captcha}

  import_types Absinthe.Type.Custom

  # Types
  object :user do
    field :id, :id
    field :email, :string
    field :name, :string
    field :is_admin, :boolean
    field :role, :string
    field :inserted_at, :datetime
    field :updated_at, :datetime
  end

  object :game_stats do
    field :total_score, :integer
    field :total_playtime, :integer
    field :games_played, :integer
    field :highest_level, :integer
  end

  # Queries
  query do
    field :current_user, :user do
      resolve fn _, %{context: %{current_user: user}} ->
        {:ok, user}
      end
    end

    field :game_stats, :game_stats do
      resolve fn _, _ ->
        stats = Game.get_game_stats()
        {:ok, stats}
      end
    end


  end

  # Mutations
  mutation do
    field :login, :user do
      arg :email, non_null(:string)
      arg :password, non_null(:string)
      arg :captcha_token, :string

      resolve fn %{email: email, password: password} = args, %{context: context} ->
        # Verify CAPTCHA if token provided and enabled
        with :ok <- verify_captcha_if_needed(args[:captcha_token], context),
             {:ok, user} <- Accounts.authenticate_user(email, password) do
          {:ok, user}
        else
          {:error, :captcha_failed} -> {:error, "CAPTCHA verification failed"}
          {:error, _} -> {:error, "Invalid credentials"}
        end
      end
    end

    field :register, :user do
      arg :email, non_null(:string)
      arg :password, non_null(:string)
      arg :name, :string
      arg :captcha_token, :string

      resolve fn args, %{context: context} ->
        # Verify CAPTCHA if token provided and enabled
        with :ok <- verify_captcha_if_needed(args[:captcha_token], context) do
          user_params = %{
            "email" => args.email,
            "password" => args.password,
            "name" => args[:name] || args.email
          }

          case Accounts.register_user(user_params) do
            {:ok, user} -> {:ok, user}
            {:error, changeset} -> 
              errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
              {:error, "Registration failed: #{inspect(errors)}"}
          end
        else
          {:error, :captcha_failed} -> {:error, "CAPTCHA verification failed"}
        end
      end
    end


  end

  # Helper function for CAPTCHA verification
  defp verify_captcha_if_needed(nil, _context), do: :ok
  defp verify_captcha_if_needed("", _context), do: :ok
  defp verify_captcha_if_needed(captcha_token, context) do
    remote_ip = get_remote_ip(context)
    
    case Captcha.verify_hcaptcha(captcha_token, remote_ip) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :captcha_failed}
    end
  end

  defp get_remote_ip(%{conn: conn}) when not is_nil(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] -> 
        forwarded |> String.split(",") |> List.first() |> String.trim()
      [] ->
        case Plug.Conn.get_req_header(conn, "x-real-ip") do
          [real_ip | _] -> real_ip
          [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
        end
    end
  end
  defp get_remote_ip(_), do: nil

  # Context function to add current user to resolution context
  def context(ctx) do
    loader = Dataloader.new()
    |> Dataloader.add_source(:db, Dataloader.Ecto.new(PhoenixApp.Repo))

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end
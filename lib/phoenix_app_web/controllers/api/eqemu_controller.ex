defmodule PhoenixAppWeb.Api.EqemuController do
  use PhoenixAppWeb, :controller
  
  alias PhoenixApp.Accounts
  alias PhoenixApp.EqemuGame

  def authenticate(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_for_eqemu(email, password) do
      {:ok, %{user: user, account: account}} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          user: %{
            id: user.id,
            email: user.email,
            name: user.name,
            is_admin: user.is_admin
          },
          account: %{
            id: account.id,
            eqemu_id: account.eqemu_id,
            name: account.name,
            status: account.status,
            expansion: account.expansion
          }
        })
      
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          error: to_string(reason)
        })
    end
  end

  def verify_account(conn, %{"account_name" => account_name}) do
    case Accounts.verify_eqemu_account(account_name) do
      {:ok, account} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          account: %{
            id: account.id,
            eqemu_id: account.eqemu_id,
            name: account.name,
            status: account.status,
            expansion: account.expansion,
            user: %{
              id: account.user.id,
              email: account.user.email,
              name: account.user.name,
              is_admin: account.user.is_admin
            }
          }
        })
      
      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: to_string(reason)
        })
    end
  end

  def list_characters(conn, %{"user_id" => user_id}) do
    case Accounts.get_user(user_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "User not found"})
      
      user ->
        characters = EqemuGame.list_user_characters(user)
        
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          characters: Enum.map(characters, fn char ->
            %{
              id: char.id,
              eqemu_id: char.eqemu_id,
              name: char.name,
              level: char.level,
              race: char.race,
              class: char.class,
              zone_id: char.zone_id,
              x: char.x,
              y: char.y,
              z: char.z,
              heading: char.heading
            }
          end)
        })
    end
  end

  def create_character(conn, %{"user_id" => user_id} = params) do
    case Accounts.get_user(user_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "User not found"})
      
      user ->
        character_params = Map.take(params, [
          "name", "race", "class", "gender", "deity", "face", "hair_color", 
          "hair_style", "beard", "beard_color", "eye_color_1", "eye_color_2",
          "drakkin_heritage", "drakkin_tattoo", "drakkin_details"
        ])
        
        case EqemuGame.create_character(user, character_params) do
          {:ok, character} ->
            conn
            |> put_status(:created)
            |> json(%{
              success: true,
              character: %{
                id: character.id,
                eqemu_id: character.eqemu_id,
                name: character.name,
                level: character.level,
                race: character.race,
                class: character.class
              }
            })
          
          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              success: false,
              errors: format_changeset_errors(changeset)
            })
        end
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
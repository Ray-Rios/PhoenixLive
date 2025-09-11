defmodule PhoenixApp.Settings do
  @moduledoc """
  The Settings context for application configuration.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp.Repo
  alias PhoenixApp.Settings.Option

  @doc """
  Sets a site option.
  """
  def set_option(name, value, autoload \\ true) do
    case Repo.get_by(Option, name: name) do
      nil ->
        %Option{}
        |> Option.changeset(%{name: name, value: value, autoload: autoload})
        |> Repo.insert()
      
      option ->
        option
        |> Option.changeset(%{value: value, autoload: autoload})
        |> Repo.update()
    end
  end

  @doc """
  Gets a site option value.
  """
  def get_option(name, default \\ nil) do
    case Repo.get_by(Option, name: name) do
      nil -> default
      option -> option.value
    end
  end

  @doc """
  Gets all options.
  """
  def list_options do
    Repo.all(Option)
  end

  @doc """
  Deletes an option.
  """
  def delete_option(name) do
    case Repo.get_by(Option, name: name) do
      nil -> {:error, :not_found}
      option -> Repo.delete(option)
    end
  end

  @doc """
  Seeds default application settings.
  """
  def seed_default_settings do
    set_option("site_name", "My Game CMS")
    set_option("site_description", "A modern game content management system")
    set_option("posts_per_page", "10")
    set_option("comments_enabled", "true")
    set_option("registration_enabled", "true")
    set_option("default_user_role", "subscriber")
  end
end
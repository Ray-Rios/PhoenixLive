defmodule PhoenixAppWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered around other layouts.
  """
  use PhoenixAppWeb, :html
  # Navigation import removed - not used

  embed_templates "layouts/*"

  @doc """
  Returns the appropriate Phoenix LiveView hook name for a background type
  """
  def background_hook_name(background_type) do
    case background_type do
      "galaxy" -> "HomeGalaxyScene"
      "nebula" -> "NebulaScene"
      "starfield" -> "StarfieldScene"
      "void" -> "VoidScene"
      _ -> "HomeGalaxyScene"  # Default fallback
    end
  end
end
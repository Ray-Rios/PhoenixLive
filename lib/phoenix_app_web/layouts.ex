defmodule PhoenixAppWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered around other layouts.
  """
  use PhoenixAppWeb, :html
  # Navigation import removed - not used

  embed_templates "layouts/*"
end
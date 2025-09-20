defmodule PhoenixAppWeb.Components.PageWrapper do
  use PhoenixAppWeb, :html
  import PhoenixAppWeb.Components.Navigation

  attr :current_user, :any, default: nil
  attr :flash, :map, default: %{}
  slot :inner_block, required: true

  def page_with_navbar(assigns) do
    ~H"""
    <.navbar current_user={@current_user} />
    <.flash_group flash={@flash} />
    <div class="page-content">
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
end
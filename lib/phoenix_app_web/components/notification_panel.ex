defmodule PhoenixAppWeb.Components.NotificationPanel do
  @moduledoc """
  Notification panel component for displaying pending invites and other notifications
  """
  use PhoenixAppWeb, :html

  @doc """
  Renders a notification panel that pops up from the taskbar
  """
  attr :show, :boolean, default: false
  attr :pending_invites, :list, default: []
  attr :current_user, :map, required: true
  attr :target, :any, default: nil

  def notification_panel(assigns) do
    ~H"""
    <%= if @show do %>
      <div 
        id="notification-panel"
        class="fixed bottom-14 right-4 w-96 max-h-[32rem] glass-dark rounded-lg shadow-2xl border border-gray-600 overflow-hidden z-50 animate-slide-up"
      >
        <div class="p-4 border-b border-gray-600 flex items-center justify-between">
          <h3 class="text-white font-semibold text-lg">Notifications</h3>
          <button
            phx-click="toggle_notifications"
            phx-target={@target}
            class="text-gray-400 hover:text-white transition-colors"
          >
            ✕
          </button>
        </div>

        <div class="overflow-y-auto max-h-96">
          <%= if Enum.empty?(@pending_invites) do %>
            <div class="p-8 text-center text-gray-400">
              <div class="text-4xl mb-2">📭</div>
              <p>No pending notifications</p>
            </div>
          <% else %>
            <div class="divide-y divide-gray-700">
              <%= for invite <- @pending_invites do %>
                <div class="p-4 hover:bg-gray-800/50 transition-colors">
                  <div class="flex items-start justify-between mb-2">
                    <div class="flex-1">
                      <div class="text-white font-medium mb-1">
                        Channel Invite
                      </div>
                      <div class="text-gray-300 text-sm mb-2">
                        <span class="font-semibold text-cyan-400"><%= invite.inviter.name || invite.inviter.email %></span>
                        invited you to
                        <span class="font-semibold text-purple-400">#<%= invite.channel.name %></span>
                      </div>
                      <%= if invite.channel.description do %>
                        <div class="text-gray-400 text-xs mb-2 italic">
                          "<%= invite.channel.description %>"
                        </div>
                      <% end %>
                      <div class="text-xs text-gray-500">
                        <%= format_relative_time(invite.inserted_at) %>
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center gap-2">
                    <button
                      type="button"
                      phx-click="accept_invite"
                      phx-value-invite_id={invite.id}
                      phx-target={@target}
                      class="flex-1 px-3 py-2 bg-green-600 hover:bg-green-700 text-white text-sm font-medium rounded transition-colors"
                    >
                      ✓ Accept
                    </button>
                    <button
                      type="button"
                      phx-click="decline_invite"
                      phx-value-invite_id={invite.id}
                      phx-target={@target}
                      class="flex-1 px-3 py-2 bg-gray-600 hover:bg-gray-700 text-white text-sm font-medium rounded transition-colors"
                    >
                      ✕ Decline
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <%= if !Enum.empty?(@pending_invites) do %>
          <div class="p-3 border-t border-gray-600 bg-gray-900/50">
            <div class="text-xs text-gray-400 text-center">
              💡 Tip: You can block users who spam invites from your profile settings
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp format_relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end
end

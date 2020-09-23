defmodule HumioLoggingExampleWeb.PageLive.Components.ChatMessage do
  use Phoenix.LiveComponent
  import HumioLoggingExampleWeb.PageLive.Helpers

  def render(assigns) do
    ~L"""
    <div id="message-<%= @id %>" class="message-row">
      <%= if @idx == 0 do %>
        <div class="user-time"><span class="user"><%= @message.user.display_name %></span></div>
      <% end %>
      <div class="content">
        <span class="time" data-tooltip="<%= format_full_timestamp(@message.timestamp) %>"><%= format_short_timestamp(@message.timestamp) %></span>
        <%= format_content(@message.content) %>
      </div>
    </div>
    """
  end
end

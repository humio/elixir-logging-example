defmodule HumioLoggingExampleWeb.PageLive do
  use HumioLoggingExampleWeb, :live_view
  import __MODULE__.Helpers
  alias HumioLoggingExample.{ChatStore, ChatStoreBot}

  alias HumioLoggingExampleWeb.PageLive.Components, as: Components
  @users [%{ nick: "humio", display_name: "Mr. Humio" }, %{ nick: "humia", display_name: "Mrs. Humio" }]

  @impl true
  def mount(%{ "user" => user }, _session, socket) do
    user = Enum.find(@users, fn u -> u.nick == user end)

    if connected?(socket), do: ChatStore.subscribe(user)

    chan_states = ChatStore.chan_states_for_user(user) |> Enum.map(&{&1.topic, &1}) |> Map.new()
    {:ok, assign(socket, user: user, chan_states: chan_states)}
  end

  @impl true
  def handle_params(%{ "topic" => topic }, _uri, socket) do
    user = socket.assigns.user
    chan_state = ChatStore.join_channel(topic, user)
    chan_states = Map.put(socket.assigns.chan_states, chan_state.topic, chan_state)
    {:noreply, assign(socket, 
      current_topic: topic, chan_states: chan_states, 
      current_users: chan_users(topic, chan_states), chans: chans(chan_states, user)
    )}
  end

  @impl true
  def handle_info(%{event: "chan_update", payload: chan_state}, socket) do
    %{ user: user, chan_states: chan_states, current_topic: current_topic } = socket.assigns

    chan_state = if chan_state.topic == current_topic do
      ChatStore.mark_messages_seen(chan_state.topic, user)
    else
      chan_state
    end

    chan_states = Map.put(chan_states, chan_state.topic, chan_state)
    current_users = chan_users(current_topic, chan_states)

    {:noreply, assign(socket, chan_states: chan_states, current_users: current_users, chans: chans(chan_states, user))}
  end

  @impl true
  def handle_event("submit-chat", %{"message" => "" }, socket), do: {:noreply, socket}

  @impl true
  def handle_event("submit-chat", %{"message" => "/delaymsg " <> range }, socket) do
    [min, max] = range
                 |> String.split("..") 
                 |> Enum.map(&Integer.parse(&1) |> elem(0))
    ChatStore.add_message_delay(socket.assigns.current_topic, min..max)
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit-chat", %{"message" => "/join #" <> topic }, socket) do
    path = Routes.live_path(socket, __MODULE__, topic, user: socket.assigns.user.nick)
    {:noreply, push_patch(socket, to: path) }
  end

  @impl true
  def handle_event("submit-chat", %{"message" => "/spammers " <> n }, socket) do
    ChatStoreBot.start_spammers(n, [socket.assigns.current_topic])
    {:noreply, socket }
  end

  @impl true
  def handle_event("submit-chat", %{"message" => "/bots" }, socket) do
    ChatStoreBot.Supervisor.bots()
    |> Enum.each(&ChatStoreBot.join_chan(socket.assigns.current_topic, &1.nick))
    {:noreply, socket }
  end

  @impl true
  def handle_event("submit-chat", %{"message" => "/bot " <> bot }, socket) do
    if bot in Enum.map(ChatStoreBot.Supervisor.bots(),&(&1.nick)) do
      ChatStoreBot.join_chan(socket.assigns.current_topic, bot)
    end
    {:noreply, socket }
  end

  @impl true
  def handle_event("submit-chat", %{"message" => "/" <> _ }, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit-chat", %{"message" => message }, socket) do
    %{ user: user, chan_states: chan_states, current_topic: current_topic } = socket.assigns
    message = %{ id: UUID.uuid4(), content: message, timestamp: NaiveDateTime.utc_now(), user: user }

    chan_state = ChatStore.add_message(current_topic, message)
    chan_states = Map.put(chan_states, current_topic, chan_state)

    {:noreply, assign(socket, chan_states: chan_states)}
  end
end

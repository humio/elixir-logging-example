defmodule HumioLoggingExample.ChatStore do
  use Agent
  require Logger

  def start_link(topic: topic) do
    res = Agent.start_link(
      fn -> %{ message_delay_range: nil, topic: topic, messages: [], users: Map.new() } end, 
      name: chat_store_name(topic)
    )

    case res do
      {:ok, pid} -> 
        Logger.info("Chat started with topic: #{topic}", 
          topic: topic, client_pid: self(), chat_pid: pid)
        {:ok, pid}
      {:error, {:already_started, pid}} -> 
        Logger.info("Continued chat with topic: #{topic}", 
          topic: topic, client_pid: self(), chat_pid: pid)
        {:ok, pid}
    end
  end

  def add_message_delay(topic, range) do
    :ok = Agent.update(chat_store_name(topic), &Map.put(&1, :message_delay_range, range))
    Logger.info("Updated chat '#{topic}' to delay: #{inspect(range)}")
  end

  def add_message(topic, message) do
    store = chat_store_name(topic)
    client_pid = self()
    :ok = Agent.update(store, &Map.update!(&1, :messages, fn messages -> 
      maybe_delay(&1)
      Logger.info("Message posted", 
        user: message.user.nick, topic: topic, 
        client_pid: client_pid, channel_pid: self())
      [ message | messages ] 
    end))
    chan_state = mark_messages_seen(topic, message.user)
    broadcast(chan_state)
  end

  defp maybe_delay(%{ message_delay_range: nil }), do: nil
  defp maybe_delay(%{ topic: topic, message_delay_range: r }) do
    delay = Enum.random(r)
    Logger.info("Delaying message to topic='#{topic}' for delay=#{delay}")
    Process.sleep(delay)
  end

  def join_channel(topic, user) do
    start_chat_process(topic)

    chan_state = Agent.get_and_update(chat_store_name(topic), fn m ->
      nm = Map.update!(m, :users, &Map.put(&1, user.nick, Map.put(user, :last_viewed, NaiveDateTime.utc_now())))
      {nm, nm}
    end)

    Logger.info("Channel joined", user: user.nick, topic: topic, client_pid: self())
    broadcast(chan_state)
  end

 def leave_channel(topic, user) do
    store = chat_store_name(topic)
    chan_state = Agent.get_and_update(store, fn m ->
      nm = Map.update!(m, :users, &Map.delete(&1, user.nick))
      {nm, nm}
    end)
    Logger.info("Channel left", user: user.nick, topic: topic, client_pid: self())
    unsubscribe(user)
    broadcast(chan_state)
  end


  def mark_messages_seen(topic, user) do
    store = chat_store_name(topic)
    Agent.get_and_update(store, fn m ->
      nm = put_in(m, [:users, user.nick, :last_viewed], NaiveDateTime.utc_now())
      {nm, nm}
    end)
  end

  def chan_states_for_user(user) do
    DynamicSupervisor.which_children(HumioLoggingExample.ChatStore.Supervisor)
    |> Enum.filter(&match?({_,pid,_,_} when is_pid(pid), &1))
    |> Enum.flat_map(&Agent.get(elem(&1,1), fn chan_state = %{ users: users } -> Enum.filter(users, fn {nick,_} -> nick == user.nick end) |> Enum.map(fn _ -> chan_state end) end))
  end

  def subscribe(user) do
    HumioLoggingExampleWeb.Endpoint.subscribe(topic(user.nick))
  end

  def unsubscribe(user) do
    HumioLoggingExampleWeb.Endpoint.unsubscribe(topic(user.nick))
  end

  defp broadcast(chan_state) do
    Enum.each(chan_state.users, fn {nick, _}  ->
      HumioLoggingExampleWeb.Endpoint.broadcast_from(self(), topic(nick), "chan_update", chan_state)
    end)
    chan_state
  end

  defp topic(topic), do: "chat-channel:#{topic}"

  defp chat_store_name(topic), do: Module.concat([__MODULE__, Topics, String.capitalize(topic)])
  defp start_chat_process(topic) do
    DynamicSupervisor.start_child(HumioLoggingExample.ChatStore.Supervisor, {__MODULE__, [topic: topic]})
  end
end

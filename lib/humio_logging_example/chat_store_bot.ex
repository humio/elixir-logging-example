defmodule HumioLoggingExample.ChatStoreBot do
  use GenServer
  require Logger
  alias HumioLoggingExample.ChatStore

  def start_link(state = %{ user: %{ nick: nick }, sentences: _, loop_range: _}) do
    GenServer.start_link(__MODULE__, Map.put_new(state, :topics, []), name: make_name(nick))
  end

  def start_spammers(n, topics \\ [])

  def start_spammers(n, topics) when is_binary(n) do
    {n, ""} = Integer.parse(n)
    start_spammers(n, topics)
  end

  def start_spammers(n, topics) when is_integer(n) do
    %{ active: min } = DynamicSupervisor.count_children(HumioLoggingExample.ChatStoreBot.SpammerSupervisor)

    max = min + n
    min = min + 1

    Enum.each(min..max, fn x ->
      state = %{ 
        user: %{ nick: "spammer#{x}", display_name: "Spammer ##{x}" },
        sentences: [ "I'm a spammer and I like to spam!" ],
        loop_range: 200..800,
        topics: topics
      }
      DynamicSupervisor.start_child(HumioLoggingExample.ChatStoreBot.SpammerSupervisor, {__MODULE__, [state]})
    end)
  end

  def stop_spammers() do
    DynamicSupervisor.which_children(HumioLoggingExample.ChatStoreBot.SpammerSupervisor)
    |> Enum.map(fn {_, pid, _, _} ->
      DynamicSupervisor.terminate_child(HumioLoggingExample.ChatStoreBot.SpammerSupervisor, pid)
    end)
  end

  def child_spec([state]) do
    %{
      id: make_name(state.user.nick),
      start: {__MODULE__, :start_link, [state]}
    }
  end

  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    Enum.each(state.topics, fn topic ->
      ChatStore.join_channel(topic, state.user)
    end)
    schedule_loop(state)
    {:ok, state}
  end

  @impl true
  def terminate(reason, %{ user: user, topics: topics }) do
    Logger.info("Terminating bot: #{user.nick}")
    Enum.each(topics, fn topic ->
      ChatStore.leave_channel(topic, user)
    end)
  end

  #client api

  def join_chan(topic, pid) when is_pid(pid) do
    GenServer.cast(pid, {:join_chan, topic})
  end

  def join_chan(topic, nick) do
    GenServer.cast(make_name(nick), {:join_chan, topic})
  end

  def leave_chan(topic, nick) do
    GenServer.cast(make_name(nick), {:leave_chan, topic})
  end

  #server api

  @impl true
  def handle_info(:loop, state = %{ topics: [] }) do
    schedule_loop(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:loop, state) do
    send_message(state)
    schedule_loop(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:join_chan, topic}, state) do
    ChatStore.join_channel(topic, state.user)
    {:noreply, Map.update!(state, :topics, &Enum.uniq([ topic | &1 ])), {:continue, []}}
  end

  def handle_cast({:leave_chan, topic}, state) do
    ChatStore.leave_channel(topic, state.user)
    {:noreply, Map.update!(state, :topics, &Enum.reject(&1, fn t -> t == topic end))}
  end

  @impl true
  def handle_continue(_, state) do
    send_message(state)
    {:noreply, state}
  end

  #helpers

  defp send_message(state) do
    topic = Enum.random(state.topics)
    Logger.info("Bot '#{state.user.nick}' sending message to '#{topic}'", topic: topic, user: state.user.nick)
    message = %{ id: UUID.uuid4(), content: Enum.random(state.sentences), timestamp: NaiveDateTime.utc_now(), user: state.user }
    ChatStore.add_message(topic, message)
  end

  defp make_name(nick) do
    Module.concat([__MODULE__, Bots, String.capitalize(nick)])
  end

  defp schedule_loop(%{ loop_range: lr }) do
    Process.send_after(self(), :loop, Enum.random(lr))
  end
end

defmodule HumioLoggingExample.ChatStoreBot.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @bots [
    %{
      user: %{ nick: "joe", display_name: "Joe" },
      sentences: [
        "Hello Mike",
      ]
    },
    %{
      user: %{ nick: "mike", display_name: "Mike" },
      sentences: [
        "Hello Joe"
      ]
    },
    %{
      user: %{ nick: "robert", display_name: "Robert" },
      sentences: [
        "Any sufficiently complicated concurrent program in another language contains an ad hoc informally-specified bug-ridden slow implementation of half of Erlang"
      ]
    },
    %{
      user: %{ nick: "erl", display_name: "E[a]rl" },
      sentences: [
        "You should try Humio!",
      ]
    },
    %{
      user: %{ nick: "jose", display_name: "Jose" },
      sentences: [
        "💚 💙 💜 💛 🧡"
      ]
    },
    %{
      user: %{ nick: "dknuth", display_name: "Dr. Knuth" },
      sentences: [
        "Premature optimization is the root of all evil.",
        "Programs are meant to be read by humans and only incidentally for computers to execute.",
        "The language in which we express our ideas has a strong influence on our thought processes.",
      ]
    }
    ]


  def bots, do: Enum.map(@bots, &(&1.user))

  @impl true
  def init(_init_arg) do

    children = @bots
               |> Enum.map(fn b ->
                 min = Enum.random(500..10_000)
                 max = Enum.random(500..5_000) + min
                 Map.put(b, :loop_range, min..max)
               end)
               |> Enum.map( &{HumioLoggingExample.ChatStoreBot, [&1]})

    Supervisor.init(children, strategy: :one_for_one)
  end
end

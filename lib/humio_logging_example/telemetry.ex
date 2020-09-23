defmodule HumioLoggingExample.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      # Add reporters as children of your supervision tree.
      {HumioLoggingExample.HumioMetricsReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total"),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      last_value("process_info.total_heap_size", tags: [:pid, :registered_name]),
      last_value("process_info.message_queue_len", tags: [:pid, :registered_name])
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {HumioLoggingExampleWeb, :count_users, []}
      {__MODULE__, :noteworthy_processes, []},
      {__MODULE__, :application_processes, []}
    ]
  end

  def application_processes() do
    process_infos = Process.list() |> Enum.map(&Process.info(&1) |> Keyword.put(:pid, &1) |> Map.new)

    processes = Enum.filter(process_infos, fn pi ->
      pi
      |> Map.get(:registered_name, :default) 
      |> Atom.to_string()
      |> String.starts_with?("Elixir.Humio")
    end)
    report_processes(processes)
  end

  def noteworthy_processes() do
    process_infos = Process.list |> Enum.map(&Process.info(&1) |> Keyword.put(:pid, &1) |> Map.new)

    by_heap = process_infos
              |> Enum.sort_by(&(&1.total_heap_size), :desc)
              |> Enum.filter(&(&1.total_heap_size >= 150_000))
              |> Enum.take(5)

    by_mq_len =
              process_infos
              |> Enum.sort_by(&(&1.message_queue_len), :desc)
              |> Enum.filter(&(&1.message_queue_len >= 5))
              |> Enum.take(5)

    processes = Enum.concat([by_heap, by_mq_len]) |> Enum.uniq_by(&(&1.pid))

    report_processes(processes)
  end

  defp report_processes(processes) do
    Enum.each(processes, fn p ->
      measurements = Map.take(p, [:total_heap_size, :reductions, :message_queue_len])
      metadata = Map.take(p, [:pid, :registered_name, :status, :group_leader])
      :telemetry.execute([:process_info], measurements, metadata)
    end)
  end
end

defimpl String.Chars, for: PID do
  def to_string(pid) do
    inspect(pid) |> String.replace(~r/#PID/, "")
  end
end

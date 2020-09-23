defmodule HumioLoggingExample.HumioMetricsReporter do
  use GenServer
  require Logger

  def start_link(opts) do
    server_opts = Keyword.take(opts, [:name])
    device = opts[:device] || :stdio

    metrics =
      opts[:metrics] ||
        raise ArgumentError, "the :metrics option is required by #{inspect(__MODULE__)}"

    GenServer.start_link(__MODULE__, {metrics, device}, server_opts)
  end

  @impl true
  def init({metrics, device}) do
    Process.flag(:trap_exit, true)
    groups = Enum.group_by(metrics, & &1.event_name)

    for {event, metrics} <- groups do
      id = {__MODULE__, event, self()}
      :telemetry.attach(id, event, &handle_event/4, {metrics, device})
    end

    {:ok, Map.keys(groups)}
  end

  @impl true
  def terminate(_, events) do
    for event <- events do
      :telemetry.detach({__MODULE__, event, self()})
    end

    :ok
  end

  defp handle_event(event_name, measurements, metadata, {metrics, device}) do
    for %struct{} = metric <- metrics do
      try do
        measurement = extract_measurement(metric, measurements)
        tags = extract_tags(metric, metadata)
        value = inspect(measurement)
        unit = unit(metric.unit)
        tag_str = Enum.map(tags, fn {key, val} -> "#{key}=\"#{val}\"" end) |> Enum.join(" ")
        unit_str = if not is_nil(unit) do
          "unit=#{unit} "
        else
          ""
        end
        measurement_str = if not is_function(metric.measurement) do 
          "measurement=\"#{inspect(metric.measurement) |> String.trim_leading(":")}\" "
        else
          ""
        end

        cond do
          is_nil(measurement) -> ""

          not keep?(metric, metadata) -> ""

          true ->
            msg = "metric=true name=#{Enum.join(event_name,".")} type=#{metric(struct)} #{measurement_str}value=#{value} #{unit_str}#{tag_str}"
            Logger.info(msg)
        end
      rescue
        e ->
          Logger.error([
            "Could not format metric #{inspect(metric)}\n",
            Exception.format(:error, e, System.stacktrace())
          ])

          """
          Errored when processing (metric skipped - handler may detach!)
          """
      end
    end
  end

  defp keep?(%{keep: nil}, _metadata), do: true
  defp keep?(metric, metadata), do: metric.keep.(metadata)

  defp extract_measurement(metric, measurements) do
    case metric.measurement do
      fun when is_function(fun, 1) -> fun.(measurements)
      key -> measurements[key]
    end
  end

  defp unit(:unit), do: nil
  defp unit(unit), do: "#{unit}"

  defp metric(Telemetry.Metrics.Counter), do: "counter"
  defp metric(Telemetry.Metrics.Distribution), do: "distribution"
  defp metric(Telemetry.Metrics.LastValue), do: "last_value"
  defp metric(Telemetry.Metrics.Sum), do: "sum"
  defp metric(Telemetry.Metrics.Summary), do: "summary"

  defp extract_tags(metric, metadata) do
    tag_values = metric.tag_values.(metadata)
    Map.take(tag_values, metric.tags)
  end
end

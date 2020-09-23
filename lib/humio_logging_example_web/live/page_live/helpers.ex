defmodule HumioLoggingExampleWeb.PageLive.Helpers do
  def format_full_timestamp(dt = %NaiveDateTime{}) do
		time_part = "#{pad_leading(dt.hour)}:#{pad_leading(dt.minute)}:#{pad_leading(dt.second)}"
		"#{month_to_string(dt.month)} #{day_to_string(dt.day)} at #{time_part}"
	end

  def format_short_timestamp(%NaiveDateTime{ hour: hour, minute: minute }) do
    "#{pad_leading(hour)}:#{pad_leading(minute)}"
	end

	defp pad_leading(time_segment) do
		String.pad_leading(to_string(time_segment), 2, "0")
	end

  defp month_to_string(1), do: "Jan"
  defp month_to_string(2), do: "Feb"
  defp month_to_string(3), do: "Mar"
  defp month_to_string(4), do: "Apr"
  defp month_to_string(5), do: "May"
  defp month_to_string(6), do: "Jun"
  defp month_to_string(7), do: "Jul"
  defp month_to_string(8), do: "Aug"
  defp month_to_string(9), do: "Sep"
  defp month_to_string(10), do: "Oct"
  defp month_to_string(11), do: "Nov"
  defp month_to_string(12), do: "Dec"

  defp day_to_string(1), do: "1st"
  defp day_to_string(2), do: "2nd"
  defp day_to_string(3), do: "3rd"
  defp day_to_string(21), do: "21st"
  defp day_to_string(22), do: "22nd"
  defp day_to_string(23), do: "23rd"
  defp day_to_string(31), do: "31st"
  defp day_to_string(n), do: "#{n}th"

	def format_content(message) do
		message
	end

  def chan_messages(current_topic, chan_states) do
    chan_states
    |> get_in([current_topic, :messages])
		|> Enum.reverse()
    |> Enum.chunk_by(&(&1.user.nick))
    |> Enum.flat_map(&Enum.with_index/1)
  end

  def chan_users(current_topic, chan_states) do
    chan_states
    |> get_in([current_topic, :users])
    |> Map.values()
    |> Enum.map(&Map.take(&1, [:display_name, :nick]))
    |> Enum.sort_by(&(&1.display_name))
  end

  defp has_new_messages(chan_state, user) do
    last_viewed = get_in(chan_state, [:users, user.nick, :last_viewed])
    case {last_viewed, chan_state.messages} do
      {:never, _} -> true
      {_, []} -> false
      {dt, [ message | _ ]} -> 
        NaiveDateTime.compare(message.timestamp, dt) == :gt
    end
  end

  def chans(chan_states, user) do
    for { chan, chan_state } <- chan_states do
      {chan, has_new_messages(chan_state, user)}
    end
  end
end

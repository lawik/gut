defmodule Gut.Conference.Speaker.Calculations.Role do
  use Ash.Resource.Calculation

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &role_for/1)
  end

  defp role_for(record) do
    workshop_count = record.workshop_count || 0
    session_count = session_count(record.sessionize_data)
    conference_count = max(0, session_count - workshop_count)

    cond do
      workshop_count > 0 and conference_count > 0 -> "Both"
      workshop_count > 0 -> "Workshop"
      conference_count > 0 -> "Conference"
      true -> nil
    end
  end

  defp session_count(%{"sessions" => sessions}) when is_list(sessions), do: length(sessions)
  defp session_count(_), do: 0
end

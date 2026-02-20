defmodule Gut.Conference.Changes.NotifyDiscord do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, record ->
      {type, name} = resource_info(record)
      changes = build_changes(changeset)

      %{"resource_type" => type, "name" => name, "changes" => changes}
      |> Gut.Workers.DiscordNotification.new()
      |> Oban.insert()

      {:ok, record}
    end)
  end

  defp build_changes(changeset) do
    changeset.attributes
    |> Map.keys()
    |> Enum.map(fn attr ->
      old = Map.get(changeset.data, attr)
      new = Map.get(changeset.attributes, attr)
      {Atom.to_string(attr), format_value(old), format_value(new)}
    end)
    |> Enum.reject(fn {_attr, old, new} -> old == new end)
    |> Enum.map(fn {attr, old, new} ->
      %{"field" => attr, "from" => old, "to" => new}
    end)
  end

  defp format_value(nil), do: nil
  defp format_value(%Date{} = d), do: Date.to_string(d)
  defp format_value(%Time{} = t), do: Time.to_string(t)
  defp format_value(v) when is_atom(v), do: Atom.to_string(v)
  defp format_value(v) when is_map(v), do: "_(complex data)_"
  defp format_value(v) when is_list(v), do: "_(list)_"
  defp format_value(v), do: to_string(v)

  defp resource_info(%Gut.Conference.Speaker{} = speaker), do: {"Speaker", speaker.full_name}
  defp resource_info(%Gut.Conference.Sponsor{} = sponsor), do: {"Sponsor", sponsor.name}
end

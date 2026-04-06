defmodule GutWeb.CsvExportController do
  use GutWeb, :controller

  require Ash.Query
  require Ash.Expr

  @speaker_text_filters ~w(full_name first_name last_name)
  @speaker_atom_filters %{"confirmed_with_hotel" => ~w(unconfirmed confirmed changed)}

  @sponsor_boolean_filters ~w(responded interested confirmed logos_received announced not_happening)
  @sponsor_status_values ~w(cold warm ok dismissed)
  @sponsor_text_filters ~w(name outreach sponsorship_level)

  @workshop_text_filters ~w(name)

  def speakers(conn, params) do
    with {:ok, user} <- require_staff(conn) do
      query =
        Ash.Query.for_read(Gut.Conference.Speaker, :read)
        |> apply_text_filters(params, @speaker_text_filters)
        |> apply_atom_filters(params, @speaker_atom_filters)
        |> apply_sort(params)

      {:ok, records} = Ash.read(query, actor: user, page: false)

      headers = [
        "Full Name",
        "First Name",
        "Last Name",
        "Arrival Date",
        "Arrival Time",
        "Leaving Date",
        "Leaving Time",
        "Hotel Stay Start",
        "Hotel Stay End",
        "Hotel Covered Start",
        "Hotel Covered End",
        "Room Number",
        "Hotel Status",
        "Sharing With",
        "Wants Early Check-in",
        "Double Bed",
        "Special Requests",
        "Notes"
      ]

      rows =
        Enum.map(records, fn s ->
          [
            s.full_name,
            s.first_name,
            s.last_name,
            s.arrival_date,
            s.arrival_time,
            s.leaving_date,
            s.leaving_time,
            s.hotel_stay_start_date,
            s.hotel_stay_end_date,
            s.hotel_covered_start_date,
            s.hotel_covered_end_date,
            s.room_number,
            s.confirmed_with_hotel,
            s.sharing_with,
            s.wants_early_checkin,
            s.double_bed,
            s.special_requests,
            s.notes
          ]
        end)

      send_csv(conn, "speakers.csv", headers, rows)
    else
      {:error, conn} -> conn
    end
  end

  def workshops(conn, params) do
    with {:ok, user} <- require_staff(conn) do
      query =
        Gut.Conference.Workshop
        |> Ash.Query.for_read(:read)
        |> Ash.Query.load([
          :workshop_room,
          :workshop_timeslot,
          :registration_count,
          :waitlist_count
        ])
        |> apply_text_filters(params, @workshop_text_filters)
        |> apply_sort(params)

      {:ok, records} = Ash.read(query, actor: user, page: false)

      headers = [
        "Name",
        "Description",
        "Limit",
        "Registered",
        "Waitlisted",
        "Room",
        "Timeslot"
      ]

      rows =
        Enum.map(records, fn w ->
          [
            w.name,
            w.description,
            w.limit,
            w.registration_count,
            w.waitlist_count,
            if(Ash.Resource.loaded?(w, :workshop_room) && w.workshop_room,
              do: w.workshop_room.name
            ),
            if(Ash.Resource.loaded?(w, :workshop_timeslot) && w.workshop_timeslot,
              do: w.workshop_timeslot.name
            )
          ]
        end)

      send_csv(conn, "workshops.csv", headers, rows)
    else
      {:error, conn} -> conn
    end
  end

  def sponsors(conn, params) do
    with {:ok, user} <- require_staff(conn) do
      query =
        Ash.Query.for_read(Gut.Conference.Sponsor, :read)
        |> apply_text_filters(params, @sponsor_text_filters)
        |> apply_boolean_filters(params, @sponsor_boolean_filters)
        |> apply_sponsor_status(params)
        |> apply_sort(params)

      {:ok, records} = Ash.read(query, actor: user, page: false)

      headers = [
        "Name",
        "Status",
        "Outreach",
        "Responded",
        "Interested",
        "Confirmed",
        "Sponsorship Level",
        "Amount (EUR)",
        "Likelihood",
        "Logos Received",
        "Announced",
        "Not Happening"
      ]

      rows =
        Enum.map(records, fn s ->
          [
            s.name,
            s.status,
            s.outreach,
            s.responded,
            s.interested,
            s.confirmed,
            s.sponsorship_level,
            s.amount_eur,
            s.likelihood,
            s.logos_received,
            s.announced,
            s.not_happening
          ]
        end)

      send_csv(conn, "sponsors.csv", headers, rows)
    else
      {:error, conn} -> conn
    end
  end

  # Filter helpers

  defp apply_text_filters(query, params, fields) do
    Enum.reduce(fields, query, fn field, q ->
      case Map.get(params, field) do
        value when is_binary(value) and value != "" ->
          Ash.Query.filter(
            q,
            contains(type(^Ash.Expr.ref(String.to_existing_atom(field)), :ci_string), ^value)
          )

        _ ->
          q
      end
    end)
  end

  defp apply_boolean_filters(query, params, fields) do
    Enum.reduce(fields, query, fn field, q ->
      case Map.get(params, field) do
        "true" ->
          Ash.Query.filter(q, ^Ash.Expr.ref(String.to_existing_atom(field)) == true)

        "false" ->
          Ash.Query.filter(q, ^Ash.Expr.ref(String.to_existing_atom(field)) == false)

        _ ->
          q
      end
    end)
  end

  defp apply_atom_filters(query, params, filter_map) do
    Enum.reduce(filter_map, query, fn {field, valid_values}, q ->
      value = Map.get(params, field)

      if is_binary(value) and value in valid_values do
        Ash.Query.filter(
          q,
          ^Ash.Expr.ref(String.to_existing_atom(field)) == ^String.to_existing_atom(value)
        )
      else
        q
      end
    end)
  end

  defp apply_sponsor_status(query, params) do
    case Map.get(params, "status") do
      value when value in @sponsor_status_values ->
        Ash.Query.filter(query, status == ^String.to_existing_atom(value))

      _ ->
        query
    end
  end

  defp apply_sort(query, params) do
    case parse_sort(Map.get(params, "sort")) do
      [] -> query
      sort_list -> Ash.Query.sort(query, sort_list)
    end
  end

  defp parse_sort(nil), do: []
  defp parse_sort(""), do: []

  defp parse_sort(sort_string) do
    sort_string
    |> String.split(",")
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(fn
      "-" <> field -> {String.to_existing_atom(field), :desc}
      field -> {String.to_existing_atom(field), :asc}
    end)
  end

  # Auth

  defp require_staff(conn) do
    case conn.assigns[:current_user] do
      %{role: :staff} = user -> {:ok, user}
      _ -> {:error, conn |> put_status(:forbidden) |> text("Forbidden") |> halt()}
    end
  end

  # CSV encoding

  defp send_csv(conn, filename, headers, rows) do
    csv_data =
      [encode_csv_row(headers) | Enum.map(rows, &encode_csv_row/1)]
      |> Enum.join("\r\n")

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv_data)
  end

  defp encode_csv_row(values) do
    values
    |> Enum.map(&encode_csv_field/1)
    |> Enum.join(",")
  end

  defp encode_csv_field(nil), do: ""
  defp encode_csv_field(true), do: "true"
  defp encode_csv_field(false), do: "false"

  defp encode_csv_field(value) when is_atom(value), do: Atom.to_string(value)

  defp encode_csv_field(value) do
    str = to_string(value)

    if String.contains?(str, [",", "\"", "\n", "\r"]) do
      "\"" <> String.replace(str, "\"", "\"\"") <> "\""
    else
      str
    end
  end
end

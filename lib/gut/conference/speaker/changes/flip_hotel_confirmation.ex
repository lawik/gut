defmodule Gut.Conference.Speaker.Changes.FlipHotelConfirmation do
  @moduledoc """
  When hotel-related fields change on a speaker, automatically sets
  `confirmed_with_hotel` to `:changed` (unless it's being explicitly set in
  this same changeset).
  """
  use Ash.Resource.Change

  @hotel_fields [
    :hotel_stay_start_date,
    :hotel_stay_end_date,
    :hotel_covered_start_date,
    :hotel_covered_end_date,
    :room_number,
    :sharing_with,
    :wants_early_checkin,
    :double_bed,
    :special_requests,
    :notes
  ]

  def change(changeset, _opts, _context) do
    hotel_field_changing? =
      Enum.any?(@hotel_fields, fn field ->
        Ash.Changeset.changing_attribute?(changeset, field)
      end)

    explicitly_setting_confirmation? =
      Ash.Changeset.changing_attribute?(changeset, :confirmed_with_hotel)

    if hotel_field_changing? and not explicitly_setting_confirmation? do
      Ash.Changeset.force_change_attribute(changeset, :confirmed_with_hotel, :changed)
    else
      changeset
    end
  end
end

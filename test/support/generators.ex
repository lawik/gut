defmodule Gut.Generators do
  use Ash.Generator

  def user(opts \\ []) do
    changeset_generator(
      Gut.Accounts.User,
      :create,
      actor: Gut.system_actor("test"),
      defaults: [
        email: sequence(:user_email, &"user#{&1}@test.com"),
        role: :staff
      ],
      overrides: opts
    )
  end

  def speaker(opts \\ []) do
    changeset_generator(
      Gut.Conference.Speaker,
      :create,
      actor: Gut.system_actor("test"),
      defaults: [
        first_name: "Ada",
        last_name: "Lovelace",
        full_name: "Ada Lovelace",
        arrival_date: nil,
        arrival_time: nil,
        leaving_date: nil,
        leaving_time: nil,
        hotel_stay_start_date: nil,
        hotel_stay_end_date: nil,
        hotel_covered_start_date: nil,
        hotel_covered_end_date: nil,
        sessionize_data: nil,
        user_id: nil
      ],
      overrides: opts
    )
  end

  def sponsor(opts \\ []) do
    changeset_generator(
      Gut.Conference.Sponsor,
      :create,
      actor: Gut.system_actor("test"),
      defaults: [
        name: "Acme Corp",
        status: :cold,
        outreach: nil,
        responded: false,
        interested: false,
        confirmed: false,
        sponsorship_level: nil,
        logos_received: false,
        announced: false,
        user_id: nil
      ],
      overrides: opts
    )
  end
end

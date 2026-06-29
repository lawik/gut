defmodule GutWeb.SpeakerLiveTest do
  use GutWeb.FeatureCase

  describe "SpeakersLive (index)" do
    test "renders speakers page", %{conn: conn} do
      conn
      |> visit("/speakers")
      |> assert_has("button", text: "Sync from Sessionize")
      |> assert_has("a", text: "Add Speaker")
      |> assert_has("a[href^='/export/speakers']", text: "Export CSV")
    end

    test "renders table structure", %{conn: conn} do
      conn
      |> visit("/speakers")
      |> assert_has("div", text: "First Name")
      |> assert_has("div", text: "Agreed")
    end

    # Flaky: navigating away from /speakers immediately races the sandbox
    # teardown. SpeakersLive's cinder table loads via start_async/handle_async,
    # an authorized read that re-checks the auth token (Token.revoked?, since
    # require_token_presence_for_authentication? is on). That async DB work can
    # run after the test's sandbox owner is stopped, raising an ownership error.
    # Skipped until the teardown race is addressed.
    @tag :skip
    test "navigates to new speaker form", %{conn: conn} do
      conn
      |> visit("/speakers")
      |> click_link("Add Speaker")
      |> assert_has("h1", text: "Adding new speaker")
    end

    test "Agreed column reflects contract approval and filters work", %{conn: conn} do
      generate(
        speaker(
          first_name: "Grace",
          last_name: "Hopper",
          full_name: "Grace Hopper",
          contract_approved_at: ~U[2026-04-01 12:00:00.000000Z],
          contract_approved_git_sha: "abc123"
        )
      )

      generate(
        speaker(
          first_name: "Ada",
          last_name: "Lovelace",
          full_name: "Ada Lovelace"
        )
      )

      # Unfiltered: both speakers shown, and the agreed row has the check icon.
      # Cinder loads rows asynchronously, so the timeout lets the data arrive
      # before we assert.
      conn
      |> visit("/speakers")
      |> assert_has("td", text: "Grace", timeout: 500)
      |> assert_has("td", text: "Ada")
      |> assert_has("span.hero-check-circle")
      # Filter to Agreed = True → only Grace remains, still has the check icon
      |> choose("input[name='filters[agreed]']", "True")
      |> assert_has("td", text: "Grace", timeout: 500)
      |> refute_has("td", text: "Ada", timeout: 500)
      |> assert_has("span.hero-check-circle")
      # Filter to Agreed = False → only Ada remains and no checks are shown
      |> choose("input[name='filters[agreed]']", "False")
      |> assert_has("td", text: "Ada", timeout: 500)
      |> refute_has("td", text: "Grace", timeout: 500)
      |> refute_has("span.hero-check-circle")
    end

    test "Plus One column filters speakers by plus one status", %{conn: conn} do
      generate(
        speaker(
          first_name: "Grace",
          last_name: "Hopper",
          full_name: "Grace Hopper",
          plus_one: true
        )
      )

      generate(
        speaker(
          first_name: "Ada",
          last_name: "Lovelace",
          full_name: "Ada Lovelace",
          plus_one: false
        )
      )

      # Unfiltered: both speakers shown
      conn
      |> visit("/speakers")
      |> assert_has("td", text: "Grace", timeout: 500)
      |> assert_has("td", text: "Ada")
      # Filter to Plus One = True → only Grace remains
      |> choose("input[name='filters[plus_one]']", "True")
      |> assert_has("td", text: "Grace", timeout: 500)
      |> refute_has("td", text: "Ada", timeout: 500)
      # Filter to Plus One = False → only Ada remains
      |> choose("input[name='filters[plus_one]']", "False")
      |> assert_has("td", text: "Ada", timeout: 500)
      |> refute_has("td", text: "Grace", timeout: 500)
    end
  end

  describe "SpeakerDetailLive (show)" do
    test "renders speaker details", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("h1", text: "Ada Lovelace")
      |> assert_has("a", text: "Edit Speaker")
      |> assert_has("a", text: "Back to Speakers")
    end

    test "shows plus one when the speaker is bringing a guest", %{conn: conn} do
      speaker = generate(speaker(plus_one: true))

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("dt", text: "Plus One")
      |> assert_has("dd", text: "Bringing a guest")
    end

    test "shows no plus one by default", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("dt", text: "Plus One")
      |> refute_has("dd", text: "Bringing a guest")
    end

    test "shows the associated user account when linked", %{conn: conn} do
      user = generate(user(email: "ada@speakers.test", role: :speaker))
      speaker = generate(speaker(user_id: user.id))

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("p", text: "Associated with user account (ada@speakers.test)")
    end

    test "omits the user account line when unlinked", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}")
      |> refute_has("p", text: "Associated with user account")
    end

    test "shows total stay duration when arrival and departure are set", %{conn: conn} do
      speaker =
        generate(
          speaker(
            arrival_date: ~D[2026-09-28],
            leaving_date: ~D[2026-10-03]
          )
        )

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("p", text: "Total Stay Duration")
      |> assert_has("p", text: "5 days")
    end

    test "shows empty states when travel and hotel data are unset", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("span", text: "Not scheduled")
      |> assert_has("dd", text: "Not assigned")
      |> assert_has("dd", text: "No one")
      |> refute_has("p", text: "Total Stay Duration")
    end

    test "shows full coverage when the stay matches the covered nights", %{conn: conn} do
      speaker =
        generate(
          speaker(
            hotel_stay_start_date: ~D[2026-09-30],
            hotel_stay_end_date: ~D[2026-10-03],
            hotel_covered_start_date: ~D[2026-09-30],
            hotel_covered_end_date: ~D[2026-10-03]
          )
        )

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("p", text: "Full Coverage")
      |> refute_has("p", text: "Partial Coverage")
    end

    test "shows partial coverage with the uncovered night count", %{conn: conn} do
      speaker =
        generate(
          speaker(
            hotel_stay_start_date: ~D[2026-09-28],
            hotel_stay_end_date: ~D[2026-10-03],
            hotel_covered_start_date: ~D[2026-09-30],
            hotel_covered_end_date: ~D[2026-10-03]
          )
        )

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("p", text: "Partial Coverage")
      |> assert_has("p", text: "2 nights not covered by the conference")
    end

    test "shows system metadata timestamps", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("dt", text: "Added to system")
      |> assert_has("dt", text: "Last updated")
    end

    test "shows travel information when set", %{conn: conn} do
      speaker =
        generate(
          speaker(
            arrival_date: ~D[2026-06-15],
            leaving_date: ~D[2026-06-18]
          )
        )

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("h2", text: "Travel Information")
      |> assert_has("dt", text: "Arrival")
      |> assert_has("dt", text: "Departure")
      |> assert_has("div", text: "2026-06-15")
      |> assert_has("div", text: "2026-06-18")
    end

    test "shows hotel information when set", %{conn: conn} do
      speaker =
        generate(
          speaker(
            hotel_stay_start_date: ~D[2026-06-14],
            hotel_stay_end_date: ~D[2026-06-18],
            hotel_covered_start_date: ~D[2026-06-14],
            hotel_covered_end_date: ~D[2026-06-18]
          )
        )

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("h2", text: "Hotel Information")
      |> assert_has("p", text: "Full Coverage")
    end

    test "shows hotel detail fields", %{conn: conn} do
      speaker =
        generate(
          speaker(
            room_number: "204",
            sharing_with: "Jane Doe",
            wants_early_checkin: true,
            double_bed: true,
            special_requests: "Vegetarian, no nuts"
          )
        )

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("dd", text: "204")
      |> assert_has("dd", text: "Jane Doe")
      |> assert_has("div", text: "Early check-in")
      |> assert_has("div", text: "Double bed")
      |> assert_has("dd", text: "Vegetarian, no nuts")
    end

    test "shows hotel status badge", %{conn: conn} do
      speaker = generate(speaker(confirmed_with_hotel: :confirmed))

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("span", text: "Confirmed")
    end

    test "shows unconfirmed status by default", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("span", text: "Unconfirmed")
    end

    test "shows notes when present", %{conn: conn} do
      speaker = generate(speaker(notes: "Arrives a day early for dinner"))

      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("h2", text: "Notes")
      |> assert_has("p", text: "Arrives a day early for dinner")
    end

    test "hides notes section when empty", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}")
      |> refute_has("h2", text: "Notes")
    end

    test "navigates to edit form", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}/edit")
      |> assert_has("h1", text: "Editing Ada Lovelace")
    end
  end

  describe "SpeakerFormLive (create)" do
    test "renders the new speaker form", %{conn: conn} do
      conn
      |> visit("/speakers/new")
      |> assert_has("h1", text: "Adding new speaker")
      |> assert_has("label", text: "Full Name")
      |> assert_has("label", text: "First Name")
      |> assert_has("label", text: "Last Name")
    end

    test "renders hotel fields in the form", %{conn: conn} do
      conn
      |> visit("/speakers/new")
      |> assert_has("label", text: "Room Number")
      |> assert_has("label", text: "Sharing With")
      |> assert_has("label", text: "Wants Early Check-in")
      |> assert_has("label", text: "Double Bed")
      |> assert_has("label", text: "Special Requests")
      |> assert_has("label", text: "Hotel Confirmation Status")
      |> assert_has("label", text: "Notes")
    end

    test "creates a speaker with valid data", %{conn: conn} do
      conn
      |> visit("/speakers/new")
      |> fill_in("Full Name", with: "Grace Hopper")
      |> fill_in("First Name", with: "Grace")
      |> fill_in("Last Name", with: "Hopper")
      |> click_button("Create Speaker")
      |> assert_has("button", text: "Sync from Sessionize")
    end

    test "creates a speaker with hotel fields", %{conn: conn} do
      conn
      |> visit("/speakers/new")
      |> fill_in("Full Name", with: "Grace Hopper")
      |> fill_in("First Name", with: "Grace")
      |> fill_in("Last Name", with: "Hopper")
      |> fill_in("Room Number", with: "305")
      |> fill_in("Sharing With", with: "Partner Name")
      |> check("Wants Early Check-in")
      |> check("Double Bed")
      |> fill_in("Special Requests", with: "Vegetarian")
      |> fill_in("Notes", with: "VIP speaker")
      |> select("Hotel Confirmation Status", option: "Confirmed")
      |> click_button("Create Speaker")
      |> assert_has("button", text: "Sync from Sessionize")
    end
  end

  describe "SpeakerFormLive (edit)" do
    test "renders the edit form with existing data", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}/edit")
      |> assert_has("h1", text: "Editing Ada Lovelace")
    end

    test "updates a speaker", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}/edit")
      |> fill_in("Full Name", with: "Ada Updated")
      |> click_button("Update Speaker")
      |> assert_has("button", text: "Sync from Sessionize")
    end

    test "updates hotel fields on a speaker", %{conn: conn} do
      speaker = generate(speaker())

      conn
      |> visit("/speakers/#{speaker.id}/edit")
      |> fill_in("Room Number", with: "101")
      |> fill_in("Sharing With", with: "Someone Else")
      |> check("Wants Early Check-in")
      |> check("Double Bed")
      |> fill_in("Special Requests", with: "No seafood")
      |> fill_in("Notes", with: "Updated notes")
      |> click_button("Update Speaker")
      |> assert_has("button", text: "Sync from Sessionize")
    end

    test "updates hotel fields and verifies on detail page", %{conn: conn} do
      speaker = generate(speaker(confirmed_with_hotel: :confirmed))

      conn
      |> visit("/speakers/#{speaker.id}/edit")
      |> fill_in("Room Number", with: "202")
      |> fill_in("Special Requests", with: "Lactose intolerant")
      |> fill_in("Notes", with: "Needs ground floor")
      |> click_button("Update Speaker")
      |> assert_has("button", text: "Sync from Sessionize")

      # Verify the data persisted by visiting the detail page
      conn
      |> visit("/speakers/#{speaker.id}")
      |> assert_has("dd", text: "202")
      |> assert_has("dd", text: "Lactose intolerant")
      |> assert_has("p", text: "Needs ground floor")
      |> assert_has("span", text: "Changed")
    end
  end
end

defmodule GutWeb.BlastLinkTest do
  @moduledoc """
  Blast emails link to /blast-link/:id?token=<magic token>. Following it
  stores the blast page as the post-sign-in destination and forwards to the
  magic-link page, so the attendee lands on the blast after signing in.
  """
  use GutWeb.ConnCase

  import Gut.Generators

  @system_actor Gut.system_actor("test")

  test "with a token forwards to the magic-link page and stores the blast as destination",
       %{conn: conn} do
    blast_id = Ash.UUID.generate()

    conn = get(conn, "/blast-link/#{blast_id}?token=tok123")

    assert redirected_to(conn) == "/magic_link/tok123"
    assert get_session(conn, :return_to) == "/blasts/#{blast_id}"
  end

  test "without a token forwards to sign-in, keeping the destination", %{conn: conn} do
    blast_id = Ash.UUID.generate()

    conn = get(conn, "/blast-link/#{blast_id}")

    assert redirected_to(conn) == "/sign-in"
    assert get_session(conn, :return_to) == "/blasts/#{blast_id}"
  end

  test "an already signed-in user goes straight to the blast", %{conn: conn} do
    user = generate(user(role: :attendee, email: "already-in@test.com"))
    blast_id = Ash.UUID.generate()

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> GutWeb.FeatureCase.log_in_user(user)
      |> get("/blast-link/#{blast_id}?token=tok123")

    assert redirected_to(conn) == "/blasts/#{blast_id}"
  end

  test "signing in via the emailed link lands on the blast", %{conn: conn} do
    workshop = generate(workshop())
    user = generate(user(role: :attendee, email: "linked@test.com"))
    participant = generate(workshop_participant(user_id: user.id))

    {:ok, _} =
      Gut.Conference.register_for_workshop(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: @system_actor
      )

    blast =
      Gut.Conference.send_blast!(
        %{title: "Hi", body: "There", workshop_id: workshop.id},
        actor: @system_actor
      )

    {:ok, token} = Gut.Accounts.survey_link_token("linked@test.com")

    conn =
      conn
      |> Plug.Test.init_test_session(%{return_to: "/blasts/#{blast.id}"})
      |> post("/auth/user/magic_link", %{"user" => %{"token" => token}})

    assert redirected_to(conn) == "/blasts/#{blast.id}"
    assert get_session(conn, "user_token")
  end

  test "the browse link stores the browse page as destination", %{conn: conn} do
    conn = get(conn, "/browse-link?token=tok123")

    assert redirected_to(conn) == "/magic_link/tok123"
    assert get_session(conn, :return_to) == "/workshops/browse"
  end

  test "the browse link without a token forwards to sign-in", %{conn: conn} do
    conn = get(conn, "/browse-link")

    assert redirected_to(conn) == "/sign-in"
    assert get_session(conn, :return_to) == "/workshops/browse"
  end
end

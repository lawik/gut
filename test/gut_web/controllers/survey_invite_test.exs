defmodule GutWeb.SurveyInviteTest do
  @moduledoc """
  The survey send-out emails an auth link: /survey-invite/:id?token=<magic token>.
  Following it stores the survey as the post-sign-in destination and forwards
  to the magic-link page, so the attendee lands on the survey after signing in.
  """
  use GutWeb.ConnCase

  import Gut.Generators

  @system_actor Gut.system_actor("test")

  defp create_sent_survey do
    room = generate(workshop_room(limit: 30))
    slot = generate(workshop_timeslot())

    workshop =
      generate(workshop(limit: 20, workshop_room_id: room.id, workshop_timeslot_id: slot.id))

    survey =
      Gut.Conference.create_survey!(
        %{
          title: "How did we do?",
          workshop_id: workshop.id,
          questions: [%{prompt: "Feedback?", question_type: :single_line}]
        },
        actor: @system_actor
      )

    survey = Gut.Conference.submit_survey_for_review!(survey, actor: @system_actor)
    survey = Gut.Conference.send_survey!(survey, actor: @system_actor)
    %{workshop: workshop, survey: survey}
  end

  defp register_attendee(workshop, email) do
    user = generate(user(role: :attendee, email: email))
    participant = generate(workshop_participant(user_id: user.id))

    {:ok, _} =
      Gut.Conference.register_for_workshop(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: @system_actor
      )

    user
  end

  test "invite with token forwards to the magic-link page and stores the survey as destination",
       %{conn: conn} do
    survey_id = Ash.UUID.generate()

    conn = get(conn, "/survey-invite/#{survey_id}?token=tok123")

    assert redirected_to(conn) == "/magic_link/tok123"
    assert get_session(conn, :return_to) == "/surveys/#{survey_id}/respond"
  end

  test "invite without token forwards to sign-in, keeping the destination", %{conn: conn} do
    survey_id = Ash.UUID.generate()

    conn = get(conn, "/survey-invite/#{survey_id}")

    assert redirected_to(conn) == "/sign-in"
    assert get_session(conn, :return_to) == "/surveys/#{survey_id}/respond"
  end

  test "an already signed-in user goes straight to the survey", %{conn: conn} do
    user = generate(user(role: :attendee, email: "already-in@test.com"))
    survey_id = Ash.UUID.generate()

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> GutWeb.FeatureCase.log_in_user(user)
      |> get("/survey-invite/#{survey_id}?token=tok123")

    assert redirected_to(conn) == "/surveys/#{survey_id}/respond"
  end

  test "signing in via the emailed survey link lands on the survey", %{conn: conn} do
    %{workshop: workshop, survey: survey} = create_sent_survey()
    register_attendee(workshop, "invitee@test.com")

    {:ok, token} = Gut.Accounts.survey_link_token("invitee@test.com")

    conn =
      conn
      |> Plug.Test.init_test_session(%{return_to: "/surveys/#{survey.id}/respond"})
      |> post("/auth/user/magic_link", %{"user" => %{"token" => token}})

    assert redirected_to(conn) == "/surveys/#{survey.id}/respond"
    assert get_session(conn, "user_token")
  end

  test "the interstitial magic-link page renders a sign-in confirmation for survey tokens",
       %{conn: conn} do
    %{workshop: workshop} = create_sent_survey()
    register_attendee(workshop, "interstitial@test.com")

    {:ok, token} = Gut.Accounts.survey_link_token("interstitial@test.com")

    conn = get(conn, "/magic_link/#{token}")

    assert html_response(conn, 200) =~ "Sign in"
  end

  test "the sign-in page offers exactly one login flow", %{conn: conn} do
    html = conn |> get("/sign-in") |> html_response(200)

    refute html =~ "Survey link"
    refute html =~ "survey_link"
  end

  test "survey link tokens live for seven days, login links for thirty minutes" do
    generate(user(role: :attendee, email: "lifetime@test.com"))

    {:ok, survey_token} = Gut.Accounts.survey_link_token("lifetime@test.com")
    {:ok, %{"exp" => exp, "iat" => iat}} = AshAuthentication.Jwt.peek(survey_token)
    assert exp - iat == 7 * 24 * 60 * 60

    {:ok, login_token} = Gut.Accounts.magic_link_token("lifetime@test.com")
    {:ok, %{"exp" => exp, "iat" => iat}} = AshAuthentication.Jwt.peek(login_token)
    assert exp - iat == 30 * 60
  end

  test "a survey link token can only be used once", %{conn: conn} do
    %{workshop: workshop, survey: survey} = create_sent_survey()
    register_attendee(workshop, "once@test.com")

    {:ok, token} = Gut.Accounts.survey_link_token("once@test.com")

    first =
      conn
      |> Plug.Test.init_test_session(%{return_to: "/surveys/#{survey.id}/respond"})
      |> post("/auth/user/magic_link", %{"user" => %{"token" => token}})

    assert redirected_to(first) == "/surveys/#{survey.id}/respond"
    assert get_session(first, "user_token")

    second =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header(
        "user-agent",
        Plug.Conn.get_req_header(conn, "user-agent") |> List.first()
      )
      |> Plug.Test.init_test_session(%{})
      |> post("/auth/user/magic_link", %{"user" => %{"token" => token}})

    assert redirected_to(second) == "/sign-in"
    refute get_session(second, "user_token")
  end
end

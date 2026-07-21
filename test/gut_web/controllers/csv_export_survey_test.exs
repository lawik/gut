defmodule GutWeb.CsvExportSurveyTest do
  use GutWeb.ConnCase

  import Gut.Generators

  @system_actor Gut.system_actor("test")

  defp log_in(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> GutWeb.FeatureCase.log_in_user(user)
  end

  setup do
    room = generate(workshop_room(limit: 30))
    slot = generate(workshop_timeslot())

    workshop =
      generate(
        workshop(
          name: "CSV Workshop",
          limit: 20,
          workshop_room_id: room.id,
          workshop_timeslot_id: slot.id
        )
      )

    organizer = generate(user(role: :speaker, email: "organizer@test.com"))
    speaker = generate(speaker(user_id: organizer.id))

    Gut.Conference.create_workshop_speaker!(
      %{workshop_id: workshop.id, speaker_id: speaker.id},
      actor: @system_actor
    )

    survey =
      Gut.Conference.create_survey!(
        %{
          title: "CSV survey",
          workshop_id: workshop.id,
          questions: [
            %{prompt: "Say, something?", question_type: :single_line},
            %{
              prompt: "Pick one",
              question_type: :select,
              options: [%{label: "Yes"}, %{label: "No"}]
            }
          ]
        },
        actor: @system_actor
      )

    survey = Gut.Conference.submit_survey_for_review!(survey, actor: @system_actor)
    survey = Gut.Conference.send_survey!(survey, actor: @system_actor)

    attendee = generate(user(role: :attendee, email: "csv-attendee@test.com"))
    participant = generate(workshop_participant(user_id: attendee.id, name: "Comma, Person"))

    {:ok, _} =
      Gut.Conference.register_for_workshop(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: @system_actor
      )

    survey = Gut.Conference.get_survey!(survey.id, actor: @system_actor, load: [:questions])
    [q1, q2] = survey.questions

    Gut.Conference.respond_to_survey!(
      %{
        survey_id: survey.id,
        answers: [
          %{survey_question_id: q1.id, value: "It was nice"},
          %{survey_question_id: q2.id, value: "Yes"}
        ]
      },
      actor: attendee
    )

    %{workshop: workshop, organizer: organizer, survey: survey}
  end

  test "organizer can download responses as CSV", %{conn: conn, workshop: workshop} do
    organizer = Gut.Accounts.get_user_by_email!("organizer@test.com", actor: @system_actor)

    conn =
      conn
      |> log_in(organizer)
      |> get("/export/survey-responses/#{workshop.id}")

    assert response_content_type(conn, :csv) =~ "text/csv"
    body = response(conn, 200)

    assert body =~ ~s(Attendee,"Say, something?",Pick one,Submitted At)
    assert body =~ ~s("Comma, Person",It was nice,Yes,)
  end

  test "staff can download responses as CSV", %{conn: conn, workshop: workshop} do
    staff = generate(user(role: :staff, email: "staff@test.com"))

    conn =
      conn
      |> log_in(staff)
      |> get("/export/survey-responses/#{workshop.id}")

    assert response(conn, 200) =~ "Comma, Person"
  end

  test "a speaker from another workshop is refused", %{conn: conn, workshop: workshop} do
    other_speaker_user = generate(user(role: :speaker, email: "other-speaker@test.com"))
    generate(speaker(user_id: other_speaker_user.id))

    conn =
      conn
      |> log_in(other_speaker_user)
      |> get("/export/survey-responses/#{workshop.id}")

    assert response(conn, 403)
  end

  test "an attendee is refused", %{conn: conn, workshop: workshop} do
    attendee = Gut.Accounts.get_user_by_email!("csv-attendee@test.com", actor: @system_actor)

    conn =
      conn
      |> log_in(attendee)
      |> get("/export/survey-responses/#{workshop.id}")

    assert response(conn, 403)
  end

  test "an unauthenticated request is refused", %{conn: conn, workshop: workshop} do
    conn = get(conn, "/export/survey-responses/#{workshop.id}")

    assert response(conn, 403)
  end

  test "a workshop without a survey returns 404", %{conn: conn} do
    workshop = generate(workshop(name: "No Survey Workshop", limit: 10))
    staff = generate(user(role: :staff, email: "staff2@test.com"))

    conn =
      conn
      |> log_in(staff)
      |> get("/export/survey-responses/#{workshop.id}")

    assert response(conn, 404)
  end
end

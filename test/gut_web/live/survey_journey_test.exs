defmodule GutWeb.SurveyJourneyTest do
  @moduledoc """
  End-to-end journeys for workshop surveys:

  - An organizer drafts a survey in the builder and submits it to review.
  - Staff review the survey, send it to attendees or return it to draft.
  - An attendee answers the survey.
  - A user signing up for a workshop with a sent survey is pointed to it.
  - Access control for every role along the way.
  """
  use GutWeb.FeatureCase

  @system_actor Gut.system_actor("test")

  defp create_workshop_with_organizer(_context) do
    room = generate(workshop_room(name: "Big Room", limit: 30))
    slot = generate(workshop_timeslot(name: "Morning Session"))

    workshop =
      generate(
        workshop(
          name: "LiveView Deep Dive",
          limit: 20,
          workshop_room_id: room.id,
          workshop_timeslot_id: slot.id
        )
      )

    organizer = generate(user(role: :speaker, email: "organizer@test.com"))
    speaker = generate(speaker(user_id: organizer.id, full_name: "Org Anizer"))

    Gut.Conference.create_workshop_speaker!(
      %{workshop_id: workshop.id, speaker_id: speaker.id},
      actor: @system_actor
    )

    %{workshop: workshop, organizer: organizer, speaker: speaker, room: room, slot: slot}
  end

  defp create_draft_survey(workshop) do
    Gut.Conference.create_survey!(
      %{
        title: "How did we do?",
        description: "Be honest.",
        workshop_id: workshop.id,
        questions: [
          %{prompt: "What did you learn?", question_type: :single_line, required: true},
          %{
            prompt: "Would you recommend the workshop?",
            question_type: :select,
            options: [%{label: "Yes"}, %{label: "No"}]
          },
          %{prompt: "Anything else?", question_type: :multiline}
        ]
      },
      actor: @system_actor
    )
  end

  defp create_submitted_survey(workshop) do
    workshop
    |> create_draft_survey()
    |> Gut.Conference.submit_survey_for_review!(actor: @system_actor)
  end

  defp create_sent_survey(workshop) do
    survey = create_submitted_survey(workshop)
    Gut.Conference.send_survey!(survey, actor: @system_actor)
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

  defp reload_survey(survey) do
    Gut.Conference.get_survey!(survey.id, actor: @system_actor, load: [questions: [:options]])
  end

  describe "organizer journey" do
    setup [:create_workshop_with_organizer]

    test "builds a survey in the builder, saves the draft and submits it to review", %{
      conn: conn,
      organizer: organizer
    } do
      conn = log_in_user(conn, organizer)

      conn
      |> visit("/my-workshops")
      |> assert_has("h2", text: "LiveView Deep Dive")
      |> assert_has("span", text: "No survey yet")
      |> click_link("Manage survey")
      |> assert_has("h1", text: "Attendee survey for LiveView Deep Dive")
      |> fill_in("Survey title", with: "How did we do?")
      |> fill_in("Description", with: "Be honest.")
      |> click_button("Add question")
      |> fill_in("#form_questions_0_prompt", "Question", with: "What did you learn?")
      |> check("#form_questions_0_required", "Required")
      |> click_button("Add question")
      |> fill_in("#form_questions_1_prompt", "Question",
        with: "Would you recommend the workshop?"
      )
      |> select("#form_questions_1_question_type", "Answer type", option: "Select from dropdown")
      |> click_button("Add option")
      |> fill_in("#form_questions_1_options_0_label", "Option", with: "Yes")
      |> click_button("Add option")
      |> fill_in("#form_questions_1_options_1_label", "Option", with: "No")
      |> click_button("Save draft")
      |> assert_has("div", text: "Draft saved")
      |> assert_has("span", text: "Draft")
      |> click_button("Submit to Review")
      |> assert_has("span", text: "In review")
      |> assert_has("p", text: "waiting for staff review")

      [survey] = Gut.Conference.list_surveys!(actor: @system_actor, load: [questions: [:options]])
      assert survey.status == :in_review
      assert survey.title == "How did we do?"
      assert [q1, q2] = survey.questions
      assert q1.prompt == "What did you learn?"
      assert q1.question_type == :single_line
      assert q1.required == true
      assert q2.question_type == :select
      assert q2.required == false
      assert Enum.map(q2.options, & &1.label) == ["Yes", "No"]
    end

    test "can remove a question from a draft", %{
      conn: conn,
      workshop: workshop,
      organizer: organizer
    } do
      Gut.Conference.create_survey!(
        %{
          title: "How did we do?",
          workshop_id: workshop.id,
          questions: [
            %{prompt: "First question", question_type: :single_line},
            %{prompt: "Second question", question_type: :single_line}
          ]
        },
        actor: @system_actor
      )

      conn = log_in_user(conn, organizer)

      conn
      |> visit("/workshops/#{workshop.id}/survey")
      |> within("#question-form-0", fn session ->
        click_button(session, "Remove question")
      end)
      |> click_button("Save draft")
      |> assert_has("div", text: "Draft saved")

      [survey] = Gut.Conference.list_surveys!(actor: @system_actor, load: [:questions])
      assert [%{prompt: "Second question"}] = survey.questions
    end

    test "sees attendee names on the workshop card but no contact information", %{
      conn: conn,
      workshop: workshop,
      organizer: organizer
    } do
      attendee_user = generate(user(role: :attendee, email: "secret-email@test.com"))

      participant =
        generate(
          workshop_participant(
            user_id: attendee_user.id,
            name: "Adda Tendee",
            phone_number: "+46701234567"
          )
        )

      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant.id},
          actor: @system_actor
        )

      conn = log_in_user(conn, organizer)

      conn
      |> visit("/my-workshops")
      |> assert_has("h3", text: "Attendees (1)")
      |> assert_has("li", text: "Adda Tendee")
      |> refute_has("body", text: "secret-email@test.com")
      |> refute_has("body", text: "+46701234567")
    end

    test "shows a waitlist count instead of waitlisted names", %{
      conn: conn,
      organizer: organizer,
      speaker: speaker
    } do
      # A second workshop for the same organizer with room for only one person.
      room = generate(workshop_room(name: "Tiny Room", limit: 10))
      slot = generate(workshop_timeslot(name: "Afternoon Session"))

      workshop =
        generate(
          workshop(
            name: "Tiny Workshop",
            limit: 1,
            workshop_room_id: room.id,
            workshop_timeslot_id: slot.id
          )
        )

      Gut.Conference.create_workshop_speaker!(
        %{workshop_id: workshop.id, speaker_id: speaker.id},
        actor: @system_actor
      )

      for {name, email} <- [{"First Person", "first@test.com"}, {"Late Person", "late@test.com"}] do
        user = generate(user(role: :attendee, email: email))
        participant = generate(workshop_participant(user_id: user.id, name: name))

        {:ok, _} =
          Gut.Conference.register_for_workshop(
            %{workshop_id: workshop.id, workshop_participant_id: participant.id},
            actor: @system_actor
          )
      end

      conn = log_in_user(conn, organizer)

      conn
      |> visit("/my-workshops")
      |> assert_has("li", text: "First Person")
      |> assert_has("p", text: "+1 on the waitlist")
      |> refute_has("li", text: "Late Person")
    end

    test "sees a read-only view once the survey is in review", %{
      conn: conn,
      workshop: workshop,
      organizer: organizer
    } do
      create_submitted_survey(workshop)
      conn = log_in_user(conn, organizer)

      conn
      |> visit("/workshops/#{workshop.id}/survey")
      |> assert_has("span", text: "In review")
      |> assert_has("li", text: "What did you learn?")
      |> refute_has("button", text: "Save draft")
    end
  end

  describe "survey preview" do
    setup [:create_workshop_with_organizer]

    test "organizer can interactively preview a draft survey without saving anything", %{
      conn: conn,
      workshop: workshop,
      organizer: organizer
    } do
      create_draft_survey(workshop)
      conn = log_in_user(conn, organizer)

      conn
      |> visit("/workshops/#{workshop.id}/survey")
      |> click_link("Preview")
      |> assert_has("#preview-banner", text: "This is what attendees will see")
      |> assert_has("h1", text: "How did we do?")
      |> click_button("Submit answers")
      |> assert_has("p", text: "This question is required.")
      |> fill_in("What did you learn?", with: "Just trying this out")
      |> select("Would you recommend the workshop?", option: "Yes")
      |> click_button("Submit answers")
      |> assert_has("h1", text: "Thank you!")
      |> assert_has("p", text: "no answers were actually saved")
      |> click_button("Restart preview")
      |> assert_has("h1", text: "How did we do?")

      assert {:ok, []} = Gut.Conference.list_survey_responses(actor: @system_actor)
      assert {:ok, []} = Gut.Conference.list_survey_answers(actor: @system_actor)
    end

    test "preview without a survey redirects back to the builder", %{
      conn: conn,
      workshop: workshop,
      organizer: organizer
    } do
      conn = log_in_user(conn, organizer)

      conn
      |> visit("/workshops/#{workshop.id}/survey/preview")
      |> assert_has("div", text: "There is no survey to preview yet.")
      |> assert_has("h1", text: "Attendee survey for LiveView Deep Dive")
    end

    test "a speaker who does not organize the workshop cannot preview its survey", %{
      conn: conn,
      workshop: workshop
    } do
      create_draft_survey(workshop)
      other_speaker_user = generate(user(role: :speaker, email: "other-speaker@test.com"))
      generate(speaker(user_id: other_speaker_user.id))
      conn = log_in_user(conn, other_speaker_user)

      conn
      |> visit("/workshops/#{workshop.id}/survey/preview")
      |> assert_path("/my-travel")
    end

    test "staff can preview from the review page", %{conn: conn, workshop: workshop} do
      survey = create_submitted_survey(workshop)

      conn
      |> visit("/surveys/#{survey.id}/review")
      |> click_link("Preview")
      |> assert_has("#preview-banner", text: "This is what attendees will see")
      |> assert_has("h1", text: "How did we do?")
    end
  end

  describe "staff journey" do
    setup [:create_workshop_with_organizer]

    test "reviews a submitted survey and sends it to attendees", %{
      conn: conn,
      workshop: workshop
    } do
      survey = create_submitted_survey(workshop)
      register_attendee(workshop, "attendee1@test.com")

      conn
      |> visit("/surveys")
      |> assert_has("td", text: "How did we do?")
      |> assert_has("span", text: "In review")
      |> click_link("Review")
      |> assert_has("h1", text: "How did we do?")
      |> assert_has("li", text: "What did you learn?")
      |> assert_has("li", text: "Yes")
      |> click_button("Send to attendees")
      |> assert_has("div", text: "Survey sent to attendees: 1 invitation(s) queued")
      |> assert_has("span", text: "Sent")

      assert %{status: :sent, sent_at: %DateTime{}} = reload_survey(survey)
    end

    test "sending reports skipped attendees who cannot be emailed", %{
      conn: conn,
      workshop: workshop
    } do
      survey = create_submitted_survey(workshop)
      register_attendee(workshop, "reachable@test.com")
      no_user = generate(workshop_participant(name: "No Account", user_id: nil))

      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: no_user.id},
          actor: @system_actor
        )

      conn
      |> visit("/surveys/#{survey.id}/review")
      |> click_button("Send to attendees")
      |> assert_has("div", text: "invitations queued for 1 of 2 registered attendees")
    end

    test "returns a submitted survey to the organizer for changes", %{
      conn: conn,
      workshop: workshop
    } do
      survey = create_submitted_survey(workshop)

      conn
      |> visit("/surveys/#{survey.id}/review")
      |> click_button("Return to draft")
      |> assert_has("div", text: "Survey returned to draft")
      |> assert_has("span", text: "Draft")

      assert %{status: :draft} = reload_survey(survey)
    end
  end

  describe "attendee journey" do
    setup [:create_workshop_with_organizer]

    test "answers a sent survey once", %{conn: conn, workshop: workshop} do
      survey = create_sent_survey(workshop)
      attendee = register_attendee(workshop, "attendee@test.com")
      conn = log_in_user(conn, attendee)

      conn
      |> visit("/surveys/#{survey.id}/respond")
      |> assert_has("h1", text: "How did we do?")
      |> assert_has("p", text: "attendees of")
      |> assert_has("p", text: "your answers are not anonymous")
      |> fill_in("What did you learn?", with: "So much about LiveView")
      |> select("Would you recommend the workshop?", option: "Yes")
      |> fill_in("Anything else?", with: "More coffee please")
      |> click_button("Submit answers")
      |> assert_has("h1", text: "Thank you!")

      [response] =
        Gut.Conference.list_survey_responses!(actor: @system_actor, load: [:answers])

      assert response.user_id == attendee.id
      assert length(response.answers) == 3
      assert Enum.any?(response.answers, &(&1.value == "Yes"))

      conn
      |> visit("/surveys/#{survey.id}/respond")
      |> assert_has("h1", text: "Already answered")
    end

    test "signing up for a workshop with a sent survey points to the survey", %{
      conn: conn,
      workshop: workshop,
      slot: slot
    } do
      survey = create_sent_survey(workshop)
      attendee = generate(user(role: :attendee, email: "newcomer@test.com"))
      conn = log_in_user(conn, attendee)

      conn
      |> visit("/workshops/browse")
      |> unwrap(fn view ->
        view
        |> Phoenix.LiveViewTest.element(
          "div[phx-value-workshop_id='#{workshop.id}'][phx-value-timeslot_id='#{slot.id}']"
        )
        |> Phoenix.LiveViewTest.render_click()
      end)
      |> fill_in("Name *", with: "New Comer")
      |> click_button("Register")
      |> assert_has("h2", text: "Registration Complete!")
      |> assert_has("a", text: "Answer the survey for LiveView Deep Dive")
      |> click_link("Answer the survey for LiveView Deep Dive")
      |> assert_has("h1", text: "How did we do?")
      |> fill_in("What did you learn?", with: "Signed up and answering already")
      |> click_button("Submit answers")
      |> assert_has("h1", text: "Thank you!")

      [response] = Gut.Conference.list_survey_responses!(actor: @system_actor)
      assert response.survey_id == survey.id
    end

    test "required questions must be answered before submitting", %{
      conn: conn,
      workshop: workshop
    } do
      survey = create_sent_survey(workshop)
      attendee = register_attendee(workshop, "attendee@test.com")
      conn = log_in_user(conn, attendee)

      conn
      |> visit("/surveys/#{survey.id}/respond")
      |> fill_in("Anything else?", with: "Skipping the required one")
      |> click_button("Submit answers")
      |> assert_has("p", text: "This question is required.")
      |> refute_has("h1", text: "Thank you!")
      |> fill_in("What did you learn?", with: "Fine, here you go")
      |> click_button("Submit answers")
      |> assert_has("h1", text: "Thank you!")

      [response] = Gut.Conference.list_survey_responses!(actor: @system_actor, load: [:answers])
      assert Enum.any?(response.answers, &(&1.value == "Fine, here you go"))
    end

    test "an all-blank submission is rejected without consuming the response", %{
      conn: conn,
      workshop: workshop
    } do
      survey =
        Gut.Conference.create_survey!(
          %{
            title: "Optional only",
            workshop_id: workshop.id,
            questions: [%{prompt: "Optional thoughts?", question_type: :multiline}]
          },
          actor: @system_actor
        )

      survey = Gut.Conference.submit_survey_for_review!(survey, actor: @system_actor)
      survey = Gut.Conference.send_survey!(survey, actor: @system_actor)

      attendee = register_attendee(workshop, "blank@test.com")
      conn = log_in_user(conn, attendee)

      conn
      |> visit("/surveys/#{survey.id}/respond")
      |> click_button("Submit answers")
      |> assert_has("div", text: "Please answer at least one question.")
      |> refute_has("h1", text: "Thank you!")
      |> fill_in("Optional thoughts?", with: "Second try")
      |> click_button("Submit answers")
      |> assert_has("h1", text: "Thank you!")

      assert [_] = Gut.Conference.list_survey_responses!(actor: @system_actor)
    end

    test "a survey that has not been sent is not available", %{
      conn: conn,
      workshop: workshop
    } do
      survey = create_submitted_survey(workshop)
      attendee = register_attendee(workshop, "attendee@test.com")
      conn = log_in_user(conn, attendee)

      conn
      |> visit("/surveys/#{survey.id}/respond")
      |> assert_has("h1", text: "Survey not available")
    end

    test "a sent survey is not available to someone not signed up for the workshop", %{
      conn: conn,
      workshop: workshop
    } do
      survey = create_sent_survey(workshop)
      bystander = generate(user(role: :attendee, email: "bystander@test.com"))
      conn = log_in_user(conn, bystander)

      conn
      |> visit("/surveys/#{survey.id}/respond")
      |> assert_has("h1", text: "Survey not available")
    end
  end

  describe "survey results" do
    setup [:create_workshop_with_organizer]

    defp respond_as(workshop, survey, name, email) do
      user = generate(user(role: :attendee, email: email))
      participant = generate(workshop_participant(user_id: user.id, name: name))

      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant.id},
          actor: @system_actor
        )

      %{questions: [learn, recommend, _extra]} = reload_survey(survey)

      Gut.Conference.respond_to_survey!(
        %{
          survey_id: survey.id,
          answers: [
            %{survey_question_id: learn.id, value: "Answer from #{name}"},
            %{survey_question_id: recommend.id, value: "Yes"}
          ]
        },
        actor: user
      )
    end

    test "organizer sees attendee names with answers in question columns, paged", %{
      conn: conn,
      workshop: workshop,
      organizer: organizer
    } do
      survey = create_sent_survey(workshop)

      for n <- 1..11 do
        name = "Attendee #{String.pad_leading(to_string(n), 2, "0")}"
        respond_as(workshop, survey, name, "results-attendee-#{n}@test.com")
      end

      conn = log_in_user(conn, organizer)

      conn
      |> visit("/workshops/#{workshop.id}/survey/results")
      |> assert_has("th", text: "Attendee")
      |> assert_has("th", text: "What did you learn?")
      |> assert_has("th", text: "Would you recommend the workshop?")
      |> assert_has("td", text: "Attendee 01", timeout: 500)
      |> assert_has("td", text: "Answer from Attendee 01")
      |> assert_has("td", text: "Yes")
      |> assert_has("a", text: "Export CSV")
      |> refute_has("td", text: "Attendee 11")

      conn
      |> visit("/workshops/#{workshop.id}/survey/results?page=2")
      |> assert_has("td", text: "Attendee 11", timeout: 500)
      |> refute_has("td", text: "Attendee 01")
    end

    test "unanswered optional questions show a placeholder", %{
      conn: conn,
      workshop: workshop,
      organizer: organizer
    } do
      survey = create_sent_survey(workshop)
      user = generate(user(role: :attendee, email: "sparse@test.com"))
      participant = generate(workshop_participant(user_id: user.id, name: "Sparse Answerer"))

      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant.id},
          actor: @system_actor
        )

      %{questions: [learn | _]} = reload_survey(survey)

      Gut.Conference.respond_to_survey!(
        %{
          survey_id: survey.id,
          answers: [%{survey_question_id: learn.id, value: "Only the required one"}]
        },
        actor: user
      )

      conn = log_in_user(conn, organizer)

      conn
      |> visit("/workshops/#{workshop.id}/survey/results")
      |> assert_has("td", text: "Sparse Answerer", timeout: 500)
      |> assert_has("td", text: "Only the required one")
    end

    test "a speaker from another workshop cannot see the results", %{
      conn: conn,
      workshop: workshop
    } do
      create_sent_survey(workshop)
      other_speaker_user = generate(user(role: :speaker, email: "other-speaker@test.com"))
      generate(speaker(user_id: other_speaker_user.id))
      conn = log_in_user(conn, other_speaker_user)

      conn
      |> visit("/workshops/#{workshop.id}/survey/results")
      |> assert_path("/my-travel")
    end

    test "staff reach the results from the review page", %{conn: conn, workshop: workshop} do
      survey = create_sent_survey(workshop)
      respond_as(workshop, survey, "Reviewed Person", "reviewed@test.com")

      conn
      |> visit("/surveys/#{survey.id}/review")
      |> click_link("View results")
      |> assert_has("td", text: "Reviewed Person", timeout: 500)
      |> assert_has("th", text: "What did you learn?")
    end
  end

  describe "access control" do
    setup [:create_workshop_with_organizer]

    test "attendees cannot reach the staff survey pages", %{conn: conn, workshop: workshop} do
      survey = create_submitted_survey(workshop)
      conn = log_in_as(conn, :attendee)

      conn
      |> visit("/surveys")
      |> assert_path("/workshops/browse")

      conn
      |> visit("/surveys/#{survey.id}/review")
      |> assert_path("/workshops/browse")
    end

    test "a speaker who does not organize the workshop cannot open its survey builder", %{
      conn: conn,
      workshop: workshop
    } do
      other_speaker_user = generate(user(role: :speaker, email: "other-speaker@test.com"))
      generate(speaker(user_id: other_speaker_user.id))
      conn = log_in_user(conn, other_speaker_user)

      conn
      |> visit("/workshops/#{workshop.id}/survey")
      |> assert_path("/my-travel")
    end

    test "an attendee cannot open the survey builder", %{conn: conn, workshop: workshop} do
      conn = log_in_as(conn, :attendee)

      conn
      |> visit("/workshops/#{workshop.id}/survey")
      |> assert_path("/workshops/browse")
    end

    test "answering a survey requires logging in", %{pid: pid, workshop: workshop} do
      survey = create_sent_survey(workshop)
      conn = build_unauthenticated_conn(pid)

      conn
      |> visit("/surveys/#{survey.id}/respond")
      |> assert_path("/sign-in")
    end

    test "staff can open the survey builder for any workshop", %{
      conn: conn,
      workshop: workshop
    } do
      conn
      |> visit("/workshops/#{workshop.id}/survey")
      |> assert_has("h1", text: "Attendee survey for LiveView Deep Dive")
    end
  end
end

defmodule Gut.Conference.SurveyTest do
  @moduledoc """
  Unit tests for the full survey journey:

  1. A workshop organizer (a speaker on the workshop) drafts a survey with
     questions, saves the draft and submits it to review.
  2. Staff review the survey and either return it to draft or send it out
     to all registered attendees of the workshop (by email with auth link).
  3. Attendees of the workshop can then read the survey and respond once.
  """
  use Gut.DataCase

  @system_actor Gut.system_actor("test")
  @public_actor Gut.public_actor()

  @questions [
    %{prompt: "What did you think of the workshop?", question_type: :multiline},
    %{
      prompt: "Which editor do you use?",
      question_type: :select,
      options: [%{label: "Vim"}, %{label: "Emacs"}, %{label: "Other"}]
    },
    %{prompt: "One word to describe the day", question_type: :single_line}
  ]

  defp workshop_with_organizer(opts \\ []) do
    room = generate(workshop_room(limit: Keyword.get(opts, :room_limit, 30)))
    slot = generate(workshop_timeslot())

    workshop =
      generate(
        workshop(
          limit: Keyword.get(opts, :limit, 20),
          workshop_room_id: room.id,
          workshop_timeslot_id: slot.id
        )
      )

    organizer = generate(user(role: :speaker))
    speaker = generate(speaker(user_id: organizer.id))

    Gut.Conference.create_workshop_speaker!(
      %{workshop_id: workshop.id, speaker_id: speaker.id},
      actor: @system_actor
    )

    %{workshop: workshop, organizer: organizer, speaker: speaker, room: room, slot: slot}
  end

  defp register_attendee(workshop) do
    user = generate(user(role: :attendee))
    participant = generate(workshop_participant(user_id: user.id))

    {:ok, participation} =
      Gut.Conference.register_for_workshop(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: @system_actor
      )

    %{user: user, participant: participant, participation: participation}
  end

  defp draft_survey(workshop, actor, questions \\ @questions) do
    Gut.Conference.create_survey!(
      %{
        title: "Attendee survey",
        description: "Help us improve",
        workshop_id: workshop.id,
        questions: questions
      },
      actor: actor
    )
  end

  defp sent_survey(workshop) do
    survey = draft_survey(workshop, @system_actor)
    survey = Gut.Conference.submit_survey_for_review!(survey, actor: @system_actor)
    Gut.Conference.send_survey!(survey, actor: @system_actor)
  end

  defp loaded(survey, actor) do
    Gut.Conference.get_survey!(survey.id, actor: actor, load: [questions: [:options]])
  end

  describe "creating a survey" do
    setup do
      workshop_with_organizer()
    end

    test "organizer can create a draft survey with all three question types", %{
      workshop: workshop,
      organizer: organizer
    } do
      survey = draft_survey(workshop, organizer)

      assert survey.status == :draft
      assert survey.workshop_id == workshop.id

      survey = loaded(survey, organizer)
      assert [q1, q2, q3] = survey.questions
      assert q1.prompt == "What did you think of the workshop?"
      assert q1.question_type == :multiline
      assert q2.question_type == :select
      assert Enum.map(q2.options, & &1.label) == ["Vim", "Emacs", "Other"]
      assert q3.question_type == :single_line
      assert [0, 1, 2] = Enum.map(survey.questions, & &1.position)
    end

    test "organizer cannot create a survey for a workshop they do not organize", %{
      organizer: organizer
    } do
      other = workshop_with_organizer()

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_survey(
                 %{title: "Sneaky", workshop_id: other.workshop.id},
                 actor: organizer
               )
    end

    test "attendee cannot create a survey", %{workshop: workshop} do
      %{user: attendee} = register_attendee(workshop)

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_survey(
                 %{title: "Nope", workshop_id: workshop.id},
                 actor: attendee
               )
    end

    test "public actor cannot create a survey", %{workshop: workshop} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.create_survey(
                 %{title: "Nope", workshop_id: workshop.id},
                 actor: @public_actor
               )
    end

    test "staff can create a survey", %{workshop: workshop} do
      staff = generate(user(role: :staff))

      assert %{status: :draft} =
               Gut.Conference.create_survey!(
                 %{title: "Staff survey", workshop_id: workshop.id},
                 actor: staff
               )
    end

    test "a workshop can only have one survey", %{workshop: workshop, organizer: organizer} do
      draft_survey(workshop, organizer)

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.create_survey(
                 %{title: "Second", workshop_id: workshop.id},
                 actor: organizer
               )
    end
  end

  describe "editing a draft" do
    setup do
      context = workshop_with_organizer()
      Map.put(context, :survey, draft_survey(context.workshop, context.organizer))
    end

    test "organizer can update title and replace questions", %{
      survey: survey,
      organizer: organizer
    } do
      updated =
        Gut.Conference.update_survey_draft!(
          survey,
          %{
            title: "Better title",
            questions: [%{prompt: "Only question left", question_type: :single_line}]
          },
          actor: organizer
        )

      assert updated.title == "Better title"

      updated = loaded(updated, organizer)
      assert [%{prompt: "Only question left"}] = updated.questions
    end

    test "organizer can edit an existing question and its options", %{
      survey: survey,
      organizer: organizer
    } do
      %{questions: [q1, q2, q3]} = loaded(survey, organizer)
      [vim, _emacs, other] = q2.options

      updated =
        Gut.Conference.update_survey_draft!(
          survey,
          %{
            questions: [
              %{id: q1.id, prompt: q1.prompt, question_type: q1.question_type},
              %{
                id: q2.id,
                prompt: "Which editor do you REALLY use?",
                question_type: :select,
                options: [
                  %{id: vim.id, label: "Vim"},
                  %{id: other.id, label: "Something else"},
                  %{label: "Helix"}
                ]
              },
              %{id: q3.id, prompt: q3.prompt, question_type: q3.question_type}
            ]
          },
          actor: organizer
        )

      %{questions: [_, q2, _]} = loaded(updated, organizer)
      assert q2.prompt == "Which editor do you REALLY use?"
      assert Enum.map(q2.options, & &1.label) == ["Vim", "Something else", "Helix"]
    end

    test "a speaker from another workshop cannot edit the survey", %{survey: survey} do
      other = workshop_with_organizer()

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.update_survey_draft(survey, %{title: "Hijacked"},
                 actor: other.organizer
               )
    end

    test "attendee cannot edit the survey", %{survey: survey, workshop: workshop} do
      %{user: attendee} = register_attendee(workshop)

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.update_survey_draft(survey, %{title: "Hijacked"}, actor: attendee)
    end

    test "organizer can delete a draft survey", %{survey: survey, organizer: organizer} do
      assert :ok = Gut.Conference.destroy_survey(survey, actor: organizer)
      assert {:ok, []} = Gut.Conference.list_surveys(actor: organizer)
    end
  end

  describe "submitting to review" do
    setup do
      context = workshop_with_organizer()
      Map.put(context, :survey, draft_survey(context.workshop, context.organizer))
    end

    test "organizer can submit a draft to review", %{survey: survey, organizer: organizer} do
      assert %{status: :in_review} =
               Gut.Conference.submit_survey_for_review!(survey, actor: organizer)
    end

    test "a survey cannot be submitted twice", %{survey: survey, organizer: organizer} do
      survey = Gut.Conference.submit_survey_for_review!(survey, actor: organizer)

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.submit_survey_for_review(survey, actor: organizer)
    end

    test "attendee cannot submit the survey to review", %{survey: survey, workshop: workshop} do
      %{user: attendee} = register_attendee(workshop)

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.submit_survey_for_review(survey, actor: attendee)
    end

    test "the survey can no longer be edited while in review", %{
      survey: survey,
      organizer: organizer
    } do
      survey = Gut.Conference.submit_survey_for_review!(survey, actor: organizer)

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.update_survey_draft(survey, %{title: "Too late"}, actor: organizer)
    end

    test "organizer cannot delete a survey in review", %{survey: survey, organizer: organizer} do
      survey = Gut.Conference.submit_survey_for_review!(survey, actor: organizer)

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.destroy_survey(survey, actor: organizer)
    end

    test "staff can return a survey in review to draft, organizer cannot", %{
      survey: survey,
      organizer: organizer
    } do
      staff = generate(user(role: :staff))
      survey = Gut.Conference.submit_survey_for_review!(survey, actor: organizer)

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.return_survey_to_draft(survey, actor: organizer)

      assert %{status: :draft} = Gut.Conference.return_survey_to_draft!(survey, actor: staff)
    end

    test "organizer can edit again after staff return the survey to draft", %{
      survey: survey,
      organizer: organizer
    } do
      staff = generate(user(role: :staff))
      survey = Gut.Conference.submit_survey_for_review!(survey, actor: organizer)
      survey = Gut.Conference.return_survey_to_draft!(survey, actor: staff)

      assert %{title: "Revised"} =
               Gut.Conference.update_survey_draft!(survey, %{title: "Revised"}, actor: organizer)
    end
  end

  describe "sending the survey" do
    setup do
      context = workshop_with_organizer(limit: 2)
      survey = draft_survey(context.workshop, context.organizer)
      survey = Gut.Conference.submit_survey_for_review!(survey, actor: context.organizer)
      Map.put(context, :survey, survey)
    end

    test "staff can send a survey in review", %{survey: survey} do
      staff = generate(user(role: :staff))

      sent = Gut.Conference.send_survey!(survey, actor: staff)
      assert sent.status == :sent
      assert sent.sent_at != nil
    end

    test "sending emails all registered attendees with an auth link, skipping the waitlist",
         %{survey: survey, workshop: workshop} do
      staff = generate(user(role: :staff))

      # Workshop limit is 2: the first two are registered, the third waitlisted.
      %{user: first} = register_attendee(workshop)
      %{user: second} = register_attendee(workshop)
      %{user: waitlisted, participation: participation} = register_attendee(workshop)
      assert participation.status == :waitlisted

      Gut.Conference.send_survey!(survey, actor: staff)

      assert_receive {:email, email1}
      assert_receive {:email, email2}
      refute_receive {:email, _}

      recipients =
        [email1, email2]
        |> Enum.flat_map(& &1.to)
        |> Enum.map(fn {_name, address} -> address end)
        |> Enum.sort()

      assert recipients == Enum.sort([to_string(first.email), to_string(second.email)])
      refute to_string(waitlisted.email) in recipients

      for email <- [email1, email2] do
        assert email.subject =~ "Survey for"
        assert email.html_body =~ "/survey-invite/#{survey.id}?token="
      end
    end

    test "organizer cannot send the survey", %{survey: survey, organizer: organizer} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.send_survey(survey, actor: organizer)
    end

    test "a draft survey cannot be sent", %{workshop: _workshop} do
      staff = generate(user(role: :staff))
      other = workshop_with_organizer()
      draft = draft_survey(other.workshop, other.organizer)

      assert {:error, %Ash.Error.Invalid{}} = Gut.Conference.send_survey(draft, actor: staff)
    end

    test "a sent survey can no longer be edited, not even by staff", %{survey: survey} do
      staff = generate(user(role: :staff))
      sent = Gut.Conference.send_survey!(survey, actor: staff)

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.update_survey_draft(sent, %{title: "Too late"}, actor: staff)
    end
  end

  describe "attendee visibility" do
    setup do
      workshop_with_organizer()
    end

    test "attendee of the workshop can read a sent survey with questions and options", %{
      workshop: workshop
    } do
      survey = sent_survey(workshop)
      %{user: attendee} = register_attendee(workshop)

      survey = loaded(survey, attendee)
      assert length(survey.questions) == 3
      assert %{options: [_, _, _]} = Enum.find(survey.questions, &(&1.question_type == :select))
    end

    test "attendee cannot see a draft or in-review survey", %{
      workshop: workshop,
      organizer: organizer
    } do
      survey = draft_survey(workshop, organizer)
      %{user: attendee} = register_attendee(workshop)

      assert {:ok, []} = Gut.Conference.list_surveys(actor: attendee)

      Gut.Conference.submit_survey_for_review!(survey, actor: organizer)
      assert {:ok, []} = Gut.Conference.list_surveys(actor: attendee)
    end

    test "a user who is not signed up for the workshop cannot see the sent survey", %{
      workshop: workshop
    } do
      sent_survey(workshop)
      bystander = generate(user(role: :attendee))

      assert {:ok, []} = Gut.Conference.list_surveys(actor: bystander)
    end

    test "public actor cannot see surveys", %{workshop: workshop} do
      sent_survey(workshop)

      assert {:ok, []} = Gut.Conference.list_surveys(actor: @public_actor)
    end

    test "organizer sees their own survey, staff sees all", %{
      workshop: workshop,
      organizer: organizer
    } do
      draft_survey(workshop, organizer)
      other = workshop_with_organizer()
      draft_survey(other.workshop, other.organizer)
      staff = generate(user(role: :staff))

      assert {:ok, [_]} = Gut.Conference.list_surveys(actor: organizer)
      assert {:ok, [_, _]} = Gut.Conference.list_surveys(actor: staff)
    end
  end

  describe "required questions" do
    setup do
      context = workshop_with_organizer()

      survey =
        Gut.Conference.create_survey!(
          %{
            title: "Required survey",
            workshop_id: context.workshop.id,
            questions: [
              %{prompt: "Must answer", question_type: :single_line, required: true},
              %{prompt: "Optional extra", question_type: :multiline}
            ]
          },
          actor: @system_actor
        )

      survey = Gut.Conference.submit_survey_for_review!(survey, actor: @system_actor)
      survey = Gut.Conference.send_survey!(survey, actor: @system_actor)
      survey = loaded(survey, @system_actor)

      Map.merge(context, %{survey: survey, questions: survey.questions})
    end

    test "the required flag is stored on questions", %{questions: questions} do
      assert [%{prompt: "Must answer", required: true}, %{required: false}] = questions
    end

    test "a response without the required answer is rejected", %{
      workshop: workshop,
      survey: survey
    } do
      %{user: attendee} = register_attendee(workshop)

      assert {:error, %Ash.Error.Invalid{} = error} =
               Gut.Conference.respond_to_survey(
                 %{survey_id: survey.id, answers: []},
                 actor: attendee
               )

      assert Exception.message(error) =~ ~s(required questions must be answered: "Must answer")
    end

    test "a blank answer does not satisfy a required question", %{
      workshop: workshop,
      survey: survey,
      questions: [required_question | _]
    } do
      %{user: attendee} = register_attendee(workshop)

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.respond_to_survey(
                 %{
                   survey_id: survey.id,
                   answers: [%{survey_question_id: required_question.id, value: "   "}]
                 },
                 actor: attendee
               )
    end

    test "answering the required question is enough", %{
      workshop: workshop,
      survey: survey,
      questions: [required_question | _]
    } do
      %{user: attendee} = register_attendee(workshop)

      assert {:ok, _} =
               Gut.Conference.respond_to_survey(
                 %{
                   survey_id: survey.id,
                   answers: [%{survey_question_id: required_question.id, value: "Done"}]
                 },
                 actor: attendee
               )
    end
  end

  describe "responding to a survey" do
    setup do
      context = workshop_with_organizer(limit: 2)
      survey = sent_survey(context.workshop)
      survey = loaded(survey, @system_actor)
      Map.merge(context, %{survey: survey, questions: survey.questions})
    end

    defp answers_for([q1, q2, q3]) do
      [
        %{survey_question_id: q1.id, value: "It was great"},
        %{survey_question_id: q2.id, value: "Emacs"},
        %{survey_question_id: q3.id, value: "Inspiring"}
      ]
    end

    test "attendee can respond with answers to all question types", %{
      workshop: workshop,
      survey: survey,
      questions: questions
    } do
      %{user: attendee} = register_attendee(workshop)

      response =
        Gut.Conference.respond_to_survey!(
          %{survey_id: survey.id, answers: answers_for(questions)},
          actor: attendee
        )

      assert response.user_id == attendee.id

      {:ok, answers} = Gut.Conference.list_survey_answers(actor: attendee)
      assert length(answers) == 3
      assert Enum.any?(answers, &(&1.value == "Emacs"))
    end

    test "a waitlisted participant can also respond", %{workshop: workshop, survey: survey} do
      register_attendee(workshop)
      register_attendee(workshop)
      %{user: waitlisted, participation: participation} = register_attendee(workshop)
      assert participation.status == :waitlisted

      assert {:ok, _} =
               Gut.Conference.respond_to_survey(
                 %{survey_id: survey.id, answers: []},
                 actor: waitlisted
               )
    end

    test "select answers must match one of the question's options", %{
      workshop: workshop,
      survey: survey,
      questions: questions
    } do
      %{user: attendee} = register_attendee(workshop)
      select = Enum.find(questions, &(&1.question_type == :select))

      assert {:error, %Ash.Error.Invalid{} = error} =
               Gut.Conference.respond_to_survey(
                 %{
                   survey_id: survey.id,
                   answers: [%{survey_question_id: select.id, value: "Notepad"}]
                 },
                 actor: attendee
               )

      assert Exception.message(error) =~ "must be one of the question's options"
    end

    test "answers must reference questions of the same survey", %{
      workshop: workshop,
      survey: survey
    } do
      other = workshop_with_organizer()
      other_survey = loaded(sent_survey(other.workshop), @system_actor)
      [foreign_question | _] = other_survey.questions

      %{user: attendee} = register_attendee(workshop)

      assert {:error, %Ash.Error.Invalid{} = error} =
               Gut.Conference.respond_to_survey(
                 %{
                   survey_id: survey.id,
                   answers: [%{survey_question_id: foreign_question.id, value: "Sneaky"}]
                 },
                 actor: attendee
               )

      assert Exception.message(error) =~ "question does not belong to this survey"
    end

    test "an attendee can only respond once", %{
      workshop: workshop,
      survey: survey,
      questions: questions
    } do
      %{user: attendee} = register_attendee(workshop)

      Gut.Conference.respond_to_survey!(
        %{survey_id: survey.id, answers: answers_for(questions)},
        actor: attendee
      )

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.respond_to_survey(
                 %{survey_id: survey.id, answers: []},
                 actor: attendee
               )
    end

    test "responses are only accepted for sent surveys", %{workshop: _workshop} do
      other = workshop_with_organizer()
      draft = draft_survey(other.workshop, other.organizer)
      %{user: attendee} = register_attendee(other.workshop)

      assert {:error, %Ash.Error.Invalid{} = error} =
               Gut.Conference.respond_to_survey(
                 %{survey_id: draft.id, answers: []},
                 actor: attendee
               )

      assert Exception.message(error) =~ "not accepting responses"
    end

    test "a user who is not signed up for the workshop cannot respond", %{survey: survey} do
      bystander = generate(user(role: :attendee))

      assert {:error, %Ash.Error.Forbidden{}} =
               Gut.Conference.respond_to_survey(
                 %{survey_id: survey.id, answers: []},
                 actor: bystander
               )
    end

    test "responses are visible to their owner, the organizer and staff but not other attendees",
         %{workshop: workshop, survey: survey, organizer: organizer, questions: questions} do
      %{user: attendee} = register_attendee(workshop)
      %{user: other_attendee} = register_attendee(workshop)
      staff = generate(user(role: :staff))

      Gut.Conference.respond_to_survey!(
        %{survey_id: survey.id, answers: answers_for(questions)},
        actor: attendee
      )

      assert {:ok, [_]} = Gut.Conference.list_survey_responses(actor: attendee)
      assert {:ok, [_]} = Gut.Conference.list_survey_responses(actor: organizer)
      assert {:ok, [_]} = Gut.Conference.list_survey_responses(actor: staff)
      assert {:ok, []} = Gut.Conference.list_survey_responses(actor: other_attendee)

      assert {:ok, answers} = Gut.Conference.list_survey_answers(actor: organizer)
      assert length(answers) == 3
      assert {:ok, []} = Gut.Conference.list_survey_answers(actor: other_attendee)
    end
  end
end

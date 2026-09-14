defmodule Gut.Conference.BlastTest do
  @moduledoc """
  Unit tests for workshop blasts:

  1. A workshop organizer (a speaker on the workshop) or staff sends a
     Markdown blast, which is emailed to every registered attendee.
  2. Attendees of the workshop (and its organizers) can read the blast;
     nobody else can.
  """
  use Gut.DataCase
  use Oban.Testing, repo: Gut.Repo

  @system_actor Gut.system_actor("test")

  defp workshop_with_organizer do
    room = generate(workshop_room(limit: 30))
    slot = generate(workshop_timeslot())
    workshop = generate(workshop(workshop_room_id: room.id, workshop_timeslot_id: slot.id))

    organizer = generate(user(role: :speaker))
    speaker = generate(speaker(user_id: organizer.id))

    Gut.Conference.create_workshop_speaker!(
      %{workshop_id: workshop.id, speaker_id: speaker.id},
      actor: @system_actor
    )

    %{workshop: workshop, organizer: organizer}
  end

  defp register_attendee(workshop, status \\ :registered) do
    user = generate(user(role: :attendee))
    participant = generate(workshop_participant(user_id: user.id))

    {:ok, participation} =
      Gut.Conference.register_for_workshop(
        %{workshop_id: workshop.id, workshop_participant_id: participant.id},
        actor: @system_actor
      )

    participation =
      if status == :registered do
        participation
      else
        Gut.Conference.update_workshop_participation!(participation, %{status: status},
          actor: @system_actor
        )
      end

    %{user: user, participant: participant, participation: participation}
  end

  defp send_blast(workshop, actor, attrs \\ %{}) do
    Gut.Conference.send_blast(
      Map.merge(
        %{
          title: "Bring a laptop",
          body: "Please bring a **charged** laptop.",
          workshop_id: workshop.id
        },
        attrs
      ),
      actor: actor
    )
  end

  describe "sending" do
    setup do
      workshop_with_organizer()
    end

    test "the organizer can send a blast, which is stamped and queued to registered attendees",
         %{workshop: workshop, organizer: organizer} do
      %{user: a} = register_attendee(workshop)
      %{user: b} = register_attendee(workshop)
      register_attendee(workshop, :waitlisted)

      assert {:ok, blast} = send_blast(workshop, organizer)
      assert blast.sent_at
      assert blast.__metadata__[:emails_enqueued] == 2
      assert blast.__metadata__[:registered_count] == 2

      emails =
        all_enqueued(worker: Gut.Workers.BlastEmail)
        |> Enum.map(& &1.args["email"])
        |> Enum.sort()

      assert emails == Enum.sort([to_string(a.email), to_string(b.email)])
    end

    test "only registered attendees of this workshop are emailed", %{
      workshop: workshop,
      organizer: organizer
    } do
      %{user: registered} = register_attendee(workshop)
      register_attendee(workshop, :waitlisted)

      other = workshop_with_organizer()
      register_attendee(other.workshop)
      generate(user(role: :staff))

      assert {:ok, blast} = send_blast(workshop, organizer)
      assert blast.__metadata__[:emails_enqueued] == 1

      assert [job] = all_enqueued(worker: Gut.Workers.BlastEmail)
      assert job.args["email"] == to_string(registered.email)
      assert job.args["blast_id"] == blast.id
    end

    test "staff can send a blast", %{workshop: workshop} do
      staff = generate(user(role: :staff))
      assert {:ok, _blast} = send_blast(workshop, staff)
    end

    test "a speaker on another workshop cannot send a blast", %{workshop: workshop} do
      other = workshop_with_organizer()

      assert {:error, %Ash.Error.Forbidden{}} = send_blast(workshop, other.organizer)
    end

    test "an attendee cannot send a blast", %{workshop: workshop} do
      %{user: attendee} = register_attendee(workshop)

      assert {:error, %Ash.Error.Forbidden{}} = send_blast(workshop, attendee)
    end

    test "title and body are required", %{workshop: workshop, organizer: organizer} do
      assert {:error, %Ash.Error.Invalid{}} = send_blast(workshop, organizer, %{title: "  "})
      assert {:error, %Ash.Error.Invalid{}} = send_blast(workshop, organizer, %{body: ""})
      assert all_enqueued(worker: Gut.Workers.BlastEmail) == []
    end

    test "several blasts can be sent for the same workshop", %{
      workshop: workshop,
      organizer: organizer
    } do
      assert {:ok, _} = send_blast(workshop, organizer, %{title: "First"})
      assert {:ok, _} = send_blast(workshop, organizer, %{title: "Second"})

      titles =
        Gut.Conference.list_blasts!(actor: organizer) |> Enum.map(& &1.title) |> Enum.sort()

      assert titles == ["First", "Second"]
    end

    test "participants without a linked user are skipped and counted", %{
      workshop: workshop,
      organizer: organizer
    } do
      participant = generate(workshop_participant(user_id: nil))

      {:ok, _} =
        Gut.Conference.register_for_workshop(
          %{workshop_id: workshop.id, workshop_participant_id: participant.id},
          actor: @system_actor
        )

      register_attendee(workshop)

      assert {:ok, blast} = send_blast(workshop, organizer)
      assert blast.__metadata__[:emails_enqueued] == 1
      assert blast.__metadata__[:registered_count] == 2
    end
  end

  describe "the email job" do
    setup do
      %{workshop: workshop, organizer: organizer} = workshop_with_organizer()
      %{user: attendee} = register_attendee(workshop)

      {:ok, blast} =
        send_blast(workshop, organizer, %{
          title: "Room change",
          body: "We moved to **Room B**.\n\nSee the [map](https://example.com/map)."
        })

      %{workshop: workshop, blast: blast, attendee: attendee}
    end

    test "delivers the rendered Markdown with an auth link back to the blast", %{
      workshop: workshop,
      blast: blast,
      attendee: attendee
    } do
      assert :ok =
               perform_job(Gut.Workers.BlastEmail, %{
                 "blast_id" => blast.id,
                 "email" => to_string(attendee.email)
               })

      assert_receive {:email, email}
      assert [{_, to}] = email.to
      assert to == to_string(attendee.email)
      assert email.subject == "#{workshop.name}: Room change"
      assert email.html_body =~ "<strong>Room B</strong>"
      assert email.html_body =~ ~s|<a href="https://example.com/map"|
      assert email.html_body =~ "/blast-link/#{blast.id}?token="
      assert email.text_body =~ "We moved to **Room B**."
      assert email.text_body =~ "/blast-link/#{blast.id}?token="
    end

    test "escapes organizer-controlled HTML in title and body", %{workshop: workshop} do
      {:ok, blast} =
        Gut.Conference.send_blast(
          %{
            title: ~s|<script>alert("title")</script>|,
            body: ~s|Hi <script>alert("body")</script> there|,
            workshop_id: workshop.id
          },
          actor: @system_actor
        )

      assert :ok =
               perform_job(Gut.Workers.BlastEmail, %{
                 "blast_id" => blast.id,
                 "email" => "someone@test.com"
               })

      assert_receive {:email, email}
      refute email.html_body =~ "<script>"
      assert email.html_body =~ "&lt;script&gt;"
    end

    test "cancels when the blast is gone" do
      assert {:cancel, _} =
               perform_job(Gut.Workers.BlastEmail, %{
                 "blast_id" => Ash.UUID.generate(),
                 "email" => "whoever@test.com"
               })

      refute_receive {:email, _}
    end
  end

  describe "reading" do
    setup do
      %{workshop: workshop, organizer: organizer} = workshop_with_organizer()
      {:ok, blast} = send_blast(workshop, organizer)
      %{workshop: workshop, organizer: organizer, blast: blast}
    end

    test "registered and waitlisted attendees of the workshop can read it", %{blast: blast} do
      %{user: registered} = register_attendee(blast.workshop_id |> then(&%{id: &1}))
      %{user: waitlisted} = register_attendee(%{id: blast.workshop_id}, :waitlisted)

      assert {:ok, %{id: id}} = Gut.Conference.get_blast(blast.id, actor: registered)
      assert id == blast.id
      assert {:ok, _} = Gut.Conference.get_blast(blast.id, actor: waitlisted)
    end

    test "the organizer and staff can read it", %{blast: blast, organizer: organizer} do
      staff = generate(user(role: :staff))

      assert {:ok, _} = Gut.Conference.get_blast(blast.id, actor: organizer)
      assert {:ok, _} = Gut.Conference.get_blast(blast.id, actor: staff)
    end

    test "attendees of other workshops and strangers cannot read it", %{blast: blast} do
      other = workshop_with_organizer()
      %{user: other_attendee} = register_attendee(other.workshop)
      stranger = generate(user(role: :attendee))

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.get_blast(blast.id, actor: other_attendee)

      assert {:error, %Ash.Error.Invalid{}} = Gut.Conference.get_blast(blast.id, actor: stranger)

      assert {:error, %Ash.Error.Invalid{}} =
               Gut.Conference.get_blast(blast.id, actor: other.organizer)
    end
  end
end

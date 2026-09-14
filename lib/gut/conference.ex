defmodule Gut.Conference do
  use Ash.Domain, otp_app: :gut, extensions: [AshAdmin.Domain, AshAi]

  admin do
    show? true
  end

  tools do
    tool :list_speakers, Gut.Conference.Speaker, :read
    tool :get_speaker, Gut.Conference.Speaker, :read
    tool :create_speaker, Gut.Conference.Speaker, :create
    tool :update_speaker, Gut.Conference.Speaker, :update
    tool :destroy_speaker, Gut.Conference.Speaker, :destroy
    tool :list_sponsors, Gut.Conference.Sponsor, :read
    tool :get_sponsor, Gut.Conference.Sponsor, :read
    tool :create_sponsor, Gut.Conference.Sponsor, :create
    tool :update_sponsor, Gut.Conference.Sponsor, :update
    tool :destroy_sponsor, Gut.Conference.Sponsor, :destroy

    tool :list_workshop_attendance, Gut.Conference.Workshop, :attendance,
      load: [
        :capacity,
        :registration_count,
        :waitlist_count,
        :participant_count,
        :spots_remaining,
        :workshop_timeslot,
        :workshop_room
      ]

    tool :get_workshop_attendance, Gut.Conference.Workshop, :attendance,
      load: [
        :capacity,
        :registration_count,
        :waitlist_count,
        :participant_count,
        :spots_remaining,
        :workshop_timeslot,
        :workshop_room
      ]

    tool :list_timeslot_attendance, Gut.Conference.WorkshopTimeslot, :attendance,
      load: [:workshop_count, :registered_attendees, :waitlisted_attendees]
  end

  resources do
    resource Gut.Conference.Speaker do
      define :list_speakers, action: :read
      define :get_speaker, action: :read, get_by: [:id]
      define :create_speaker, action: :create
      define :update_speaker, action: :update
      define :destroy_speaker, action: :destroy
      define :sync_from_sessionize, action: :sync_from_sessionize
      define :get_own_speaker, action: :read_own
      define :update_speaker_travel, action: :update_travel
      define :update_speaker_hotel_request, action: :update_hotel_request
      define :approve_speaker_contract, action: :approve_contract
    end

    resource Gut.Conference.Sponsor do
      define :list_sponsors, action: :read
      define :get_sponsor, action: :read, get_by: [:id]
      define :create_sponsor, action: :create
      define :update_sponsor, action: :update
      define :destroy_sponsor, action: :destroy
    end

    resource Gut.Conference.WorkshopTimeslot do
      define :list_workshop_timeslots, action: :read
      define :get_workshop_timeslot, action: :read, get_by: [:id]
      define :create_workshop_timeslot, action: :create
      define :update_workshop_timeslot, action: :update
      define :destroy_workshop_timeslot, action: :destroy
      define :list_timeslot_attendance, action: :attendance
    end

    resource Gut.Conference.WorkshopRoom do
      define :list_workshop_rooms, action: :read
      define :get_workshop_room, action: :read, get_by: [:id]
      define :create_workshop_room, action: :create
      define :update_workshop_room, action: :update
      define :destroy_workshop_room, action: :destroy
    end

    resource Gut.Conference.Workshop do
      define :list_workshops, action: :read
      define :browse_workshops, action: :browse
      define :get_workshop, action: :read, get_by: [:id]
      define :create_workshop, action: :create
      define :update_workshop, action: :update
      define :destroy_workshop, action: :destroy
      define :promote_waitlist, action: :promote_waitlist, args: [:workshop_id]
      define :list_workshop_attendance, action: :attendance
      define :get_workshop_attendance, action: :attendance, get_by: [:id]
    end

    resource Gut.Conference.WorkshopSpeaker do
      define :create_workshop_speaker, action: :create
      define :destroy_workshop_speaker, action: :destroy
    end

    resource Gut.Conference.WorkshopParticipant do
      define :list_workshop_participants, action: :read
      define :get_workshop_participant, action: :read, get_by: [:id]
      define :create_workshop_participant, action: :create
      define :update_workshop_participant, action: :update
      define :destroy_workshop_participant, action: :destroy
    end

    resource Gut.Conference.WorkshopParticipation do
      define :list_workshop_participations, action: :read
      define :register_for_workshop, action: :register
      define :update_workshop_participation, action: :update
      define :destroy_workshop_participation, action: :destroy
    end

    resource Gut.Conference.Survey do
      define :list_surveys, action: :read
      define :get_survey, action: :read, get_by: [:id]
      define :create_survey, action: :create
      define :update_survey_draft, action: :update_draft
      define :submit_survey_for_review, action: :submit_for_review
      define :return_survey_to_draft, action: :return_to_draft
      define :send_survey, action: :send
      define :destroy_survey, action: :destroy
    end

    resource Gut.Conference.Blast do
      define :list_blasts, action: :read
      define :get_blast, action: :read, get_by: [:id]
      define :send_blast, action: :send
    end

    resource Gut.Conference.StatusMailing do
      define :list_status_mailings, action: :read
      define :send_status_mailing, action: :send
    end

    resource Gut.Conference.SurveyQuestion do
      define :list_survey_questions, action: :read
    end

    resource Gut.Conference.SurveyQuestionOption

    resource Gut.Conference.SurveyResponse do
      define :list_survey_responses, action: :read
      define :get_survey_response, action: :read, get_by: [:id]
      define :respond_to_survey, action: :respond
      define :destroy_survey_response, action: :destroy
      define :clear_survey_responses, action: :clear_for_survey, args: [:survey_id]
    end

    resource Gut.Conference.SurveyAnswer do
      define :list_survey_answers, action: :read
    end
  end
end

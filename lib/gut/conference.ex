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
  end

  resources do
    resource Gut.Conference.Speaker do
      define :list_speakers, action: :read
      define :get_speaker, action: :read, get_by: [:id]
      define :create_speaker, action: :create
      define :update_speaker, action: :update
      define :destroy_speaker, action: :destroy
      define :sync_from_sessionize, action: :sync_from_sessionize
    end

    resource Gut.Conference.Sponsor do
      define :list_sponsors, action: :read
      define :get_sponsor, action: :read, get_by: [:id]
      define :create_sponsor, action: :create
      define :update_sponsor, action: :update
      define :destroy_sponsor, action: :destroy
    end
  end
end

defmodule Gut.Mailer do
  use Swoosh.Mailer, otp_app: :gut

  def from_email do
    Application.get_env(:gut, __MODULE__)[:from_email]
  end
end

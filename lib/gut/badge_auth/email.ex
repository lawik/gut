defmodule Gut.BadgeAuth.Email do
  @moduledoc """
  Delivers the badge-login confirmation link.

  This is *not* a user login email — the link only confirms a badge
  device login and never signs anyone into Gut.
  """

  use GutWeb, :verified_routes

  import Swoosh.Email

  alias Gut.Mailer

  def deliver_login_link(email, auth_token) do
    link = url(~p"/badge_login/verify/#{auth_token}")

    new()
    |> from({"Goatmire", Mailer.from_email()})
    |> to(email)
    |> subject("Confirm your badge login")
    |> html_body("""
    <p>Hello!</p>
    <p>
      Someone — hopefully you — entered this email address to log in a
      conference badge at Goatmire Elixir.
    </p>
    <p><a href="#{link}">Confirm badge login</a></p>
    <p>
      After clicking the link, check your badge — it should be signed in.
      If this wasn't you, you can safely ignore this email.
    </p>
    """)
    |> Mailer.deliver!()
  end
end

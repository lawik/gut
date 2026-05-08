defmodule Gut.Conference.SpeakerAgreement do
  @moduledoc """
  Inlined speaker agreement document.

  The body contains FIRSTNAME / LASTNAME markers that are substituted with
  the speaker's real name when rendered.

  Tailwind scans this file via an `@source` directive in
  `assets/css/app.css`, so class names used here are picked up at build
  time even though the HTML is rendered as a raw string.
  """

  @body """
  <article class="text-base-content/90 leading-relaxed">
    <header class="text-center mb-10 pb-6 border-b border-base-300">
      <h1 class="text-4xl font-bold tracking-tight text-primary mb-2">
        Goatmire Elixir 2026
      </h1>
      <p class="text-sm text-base-content/60 italic">
        Varberg, Sweden &middot; 28 September – 2 October 2026
      </p>
      <p class="mt-1">
        <a href="https://www.goatmire.com" class="text-primary hover:underline">www.goatmire.com</a>
      </p>
      <h2 class="mt-6 text-base font-semibold uppercase tracking-[0.2em] text-base-content/70">
        Speaker &amp; Workshop Leader Agreement
      </h2>
    </header>

    <section class="space-y-3">
      <h3 class="text-xl font-bold text-base-content mt-8 mb-2 pb-1 border-b border-base-300/60">
        1. Parties
      </h3>
      <p>This agreement is entered into between:</p>
      <p>
        Goatmire International, ideell förening, org. nr. 802551-1596
        (hereinafter referred to as &ldquo;the Organiser&rdquo;), and
        <strong class="font-semibold text-base-content">FIRSTNAME LASTNAME</strong>
        (hereinafter referred to as &ldquo;the Presenter&rdquo;).
      </p>
    </section>

    <section class="space-y-3">
      <h3 class="text-xl font-bold text-base-content mt-8 mb-2 pb-1 border-b border-base-300/60">
        2. Conference Details
      </h3>
      <p>Goatmire Elixir 2026 takes place in Varberg, Sweden, on the following dates:</p>
      <ul class="list-disc pl-6 space-y-1 marker:text-primary/60">
        <li>Workshop days: 28–29 September 2026</li>
        <li>Conference days: 30 September – 2 October 2026</li>
      </ul>
      <p>
        Participation in workshop days is separate from participation in the
        conference. All Presenters are provided a ticket to attend the
        conference, whether workshop leader or speaker. The financial
        arrangements in Section 3 apply specifically to each role as
        indicated below.
      </p>
      <p>
        For all logistical matters, including accommodation, meals, and
        practical arrangements relating to conference participation, please
        contact Helene Mattisson at
        <a href="mailto:helene@goatmire.com" class="text-primary hover:underline">helene@goatmire.com</a>.
      </p>
    </section>

    <section class="space-y-3">
      <h3 class="text-xl font-bold text-base-content mt-8 mb-2 pb-1 border-b border-base-300/60">
        3. Financial Arrangements
      </h3>

      <h4 class="text-base font-semibold text-base-content/80 mt-5">
        3.1 Speaker Remuneration
      </h4>
      <p>
        Speaking or leading a workshop at Goatmire Elixir is an unpaid
        engagement. The Presenter will not receive a speaker fee or
        honorarium unless specifically communicated separately.
      </p>

      <h4 class="text-base font-semibold text-base-content/80 mt-5">
        3.2 Hotel Accommodation
      </h4>
      <p>
        The Organiser will cover
        <strong class="font-semibold text-base-content">three nights</strong>
        of accommodation unless a separate agreement has been made. The
        Organiser will help schedule the Presenter's stay at the hotel
        beyond the covered days.
      </p>
      <p>
        The Presenter will specify the desired duration of the stay they
        want scheduled by the Organiser in the system provided for booking
        details. If not specified before the deadline, the Organiser will
        schedule check-in on 30 September and check-out on 3 October. If
        the Presenter selects more than the covered days they will be
        billed for those days by the hotel.
      </p>
      <p>
        The current negotiated rate is 1500 SEK per night. A double room
        is +200 SEK per night for the one extra person.
      </p>
      <p>
        The recommended minimum stay to experience the workshops, conference
        and related events is arriving on 27 September and leaving on 4 October.
      </p>

      <h4 class="text-base font-semibold text-base-content/80 mt-5">
        3.3 Partner and Family Accommodation
      </h4>
      <p>
        Should the Presenter wish to bring a partner, friend and/or
        children, they must notify the Organiser at their earliest
        convenience by contacting Helene at
        <a href="mailto:helene@goatmire.com" class="text-primary hover:underline">helene@goatmire.com</a>.
        Any additional costs arising from a double room, extra beds, or
        additional guests are the sole responsibility of the Presenter and
        will be invoiced or charged accordingly.
      </p>

      <h4 class="text-base font-semibold text-base-content/80 mt-5">
        3.4 Deadline for Accommodation Changes
      </h4>
      <p>
        Any changes to accommodation logistics, including room type, number
        of guests, arrival or departure dates, or cancellations, requested
        after
        <strong class="font-semibold text-base-content">16 August 2026</strong>
        are not guaranteed to be possible.
      </p>

      <h4 class="text-base font-semibold text-base-content/80 mt-5">
        3.6 Meals
      </h4>
      <p>
        During the workshops there are no meals served. There is a break for
        lunch but none provided. If you need assistance with lunch in some
        way, do not hesitate to reach out.
      </p>
      <p>
        During the conference days lunch is provided as part of the ticket,
        as well as something to eat during certain breaks.
      </p>
      <p>
        The Organiser will host a speaker dinner on the evening of
        <strong class="font-semibold text-base-content">29 September 2026</strong>,
        to which all presenters are invited. This dinner is for presenters
        only; partners and guests are not included. If you want a special
        arrangement, reach out.
      </p>
    </section>

    <section class="space-y-3">
      <h3 class="text-xl font-bold text-base-content mt-8 mb-2 pb-1 border-b border-base-300/60">
        4. Technical Requirements
      </h3>
      <p>
        The Presenter is asked to communicate their technical requirements
        for their talk(s) or workshop(s) to the Organiser no later than
        <strong class="font-semibold text-base-content">June 2026</strong>,
        by emailing Lars at
        <a href="mailto:lars@underjord.io" class="text-primary hover:underline">lars@underjord.io</a>.
        In exceptional cases, technical requirements will be accepted up to
        <strong class="font-semibold text-base-content">1 September 2026</strong>
        as an absolute deadline. Requirements received after this date
        cannot be guaranteed to be met.
      </p>
    </section>

    <section class="space-y-3">
      <h3 class="text-xl font-bold text-base-content mt-8 mb-2 pb-1 border-b border-base-300/60">
        5. Image and Recording Rights
      </h3>
      <p>By confirming this agreement, the Presenter acknowledges and agrees that:</p>
      <ul class="list-disc pl-6 space-y-2 marker:text-primary/60">
        <li>
          They may be photographed, filmed, or otherwise recorded during
          their session(s) and throughout the conference.
        </li>
        <li>
          The Organiser and Goatmire International may use such images,
          recordings, and likenesses for the marketing and promotion of
          Goatmire Elixir and Goatmire International, before, during, and
          after the event.
        </li>
        <li>
          This includes, but is not limited to, use on the conference
          website, social media channels, newsletters, and promotional
          materials.
        </li>
      </ul>
      <p>
        All personal data collected and processed in connection with this
        agreement will be handled in accordance with applicable data
        protection legislation, including the EU General Data Protection
        Regulation (GDPR). Personal data will be processed solely for the
        purposes described in this agreement and will not be shared with
        third parties without consent.
      </p>
      <p>
        If you want any of your media removed you can reach out to
        <a href="mailto:lars@underjord.io" class="text-primary hover:underline">lars@underjord.io</a>.
      </p>
    </section>

    <section class="space-y-3">
      <h3 class="text-xl font-bold text-base-content mt-8 mb-2 pb-1 border-b border-base-300/60">
        6. Cancellation
      </h3>

      <h4 class="text-base font-semibold text-base-content/80 mt-5">
        6.1 Cancellation by the Presenter
      </h4>
      <p>
        Should the Presenter need to cancel their participation, they must
        notify the Organiser in writing by emailing Lars at
        <a href="mailto:lars@underjord.io" class="text-primary hover:underline">lars@underjord.io</a>
        as soon as possible.
      </p>

      <h4 class="text-base font-semibold text-base-content/80 mt-5">
        6.2 Cancellation of the Conference
      </h4>
      <p>
        Should Goatmire Elixir 2026 be cancelled, the Organiser will notify
        all presenters as soon as possible by email. Hotel bookings made
        within the Organiser's hotel block will be cancelled at no charge
        to the Presenter. Any accommodation booked outside the hotel block
        remains the sole responsibility of the Presenter.
      </p>
      <p>
        Goatmire International will not be liable to reimburse travel
        expenses or any other personal costs incurred by the Presenter in
        connection with their planned participation, regardless of the
        reason for cancellation.
      </p>
    </section>

    <section class="space-y-3">
      <h3 class="text-xl font-bold text-base-content mt-8 mb-2 pb-1 border-b border-base-300/60">
        7. General Provisions
      </h3>
      <p>
        This agreement constitutes the complete understanding between the
        parties regarding the Presenter's participation at Goatmire Elixir
        2026. Any amendments must be made in writing and agreed upon by
        both parties.
      </p>
      <p>
        This agreement is governed by Swedish law. Any disputes shall be
        referred to the courts of Varberg/Halland.
      </p>
    </section>
  </article>
  """

  @doc """
  Returns the agreement body with FIRSTNAME / LASTNAME substituted for
  the speaker's name.
  """
  def render(%{first_name: first_name, last_name: last_name}) do
    @body
    |> String.replace("FIRSTNAME", first_name || "")
    |> String.replace("LASTNAME", last_name || "")
  end
end

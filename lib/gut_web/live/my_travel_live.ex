defmodule GutWeb.MyTravelLive do
  use GutWeb, :live_view

  on_mount {GutWeb.LiveUserAuth, :live_user_required}

  @default_days_covered 3
  @per_night_sek 1500
  @plus_one_per_night_sek 200
  @recommended_check_in ~D[2026-09-27]
  @recommended_check_out ~D[2026-10-04]

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    case Gut.Conference.get_own_speaker(actor: user) do
      {:ok, speaker} ->
        {:ok, assign_speaker(socket, speaker, user)}

      {:error, _} ->
        socket =
          socket
          |> put_flash(:error, "No speaker profile found for your account.")
          |> assign(:page_title, "My Speaker Details")
          |> assign(:speaker, nil)
          |> assign(:approved?, false)
          |> assign(:agreement_html, nil)
          |> assign(:travel_form, nil)
          |> assign(:hotel_form, nil)
          |> assign(:hotel_summary, nil)
          |> assign(:current_scope, nil)

        {:ok, socket}
    end
  end

  defp assign_speaker(socket, speaker, user) do
    approved? = not is_nil(speaker.contract_approved_at)

    travel_form =
      speaker
      |> AshPhoenix.Form.for_update(:update_travel, actor: user)
      |> to_form()

    dates = effective_dates(speaker)

    hotel_form =
      speaker
      |> AshPhoenix.Form.for_update(:update_hotel_request,
        actor: user,
        params: %{
          "hotel_stay_start_date" => Date.to_iso8601(dates.hotel_stay_start_date),
          "hotel_stay_end_date" => Date.to_iso8601(dates.hotel_stay_end_date)
        }
      )
      |> to_form()

    socket
    |> assign(:page_title, "My Speaker Details")
    |> assign(:speaker, speaker)
    |> assign(:approved?, approved?)
    |> assign(:agreement_html, Gut.Conference.SpeakerAgreement.render(speaker))
    |> assign(:travel_form, travel_form)
    |> assign(:hotel_form, hotel_form)
    |> assign(:current_scope, nil)
    |> assign_hotel_summary(dates, speaker.plus_one)
  end

  defp effective_dates(speaker) do
    %{
      hotel_stay_start_date: speaker.hotel_stay_start_date || @recommended_check_in,
      hotel_stay_end_date: speaker.hotel_stay_end_date || @recommended_check_out
    }
  end

  defp assign_hotel_summary(socket, dates, plus_one) do
    speaker = socket.assigns.speaker
    summary = compute_summary(dates, plus_one, speaker && speaker.days_covered)
    assign(socket, :hotel_summary, summary)
  end

  defp compute_summary(
         %{hotel_stay_start_date: start_date, hotel_stay_end_date: end_date},
         plus_one,
         days_covered
       ) do
    covered = days_covered || @default_days_covered

    case nights(start_date, end_date) do
      nil ->
        %{
          nights: nil,
          covered: covered,
          uncovered: nil,
          uncovered_cost: nil,
          plus_one_cost: nil,
          total_cost: nil,
          plus_one: plus_one || false
        }

      n when n < 0 ->
        %{
          nights: n,
          covered: covered,
          uncovered: nil,
          uncovered_cost: nil,
          plus_one_cost: nil,
          total_cost: nil,
          plus_one: plus_one || false,
          invalid: true
        }

      n ->
        uncovered = max(0, n - covered)
        uncovered_cost = uncovered * @per_night_sek
        plus_one_cost = if plus_one, do: n * @plus_one_per_night_sek, else: 0

        %{
          nights: n,
          covered: covered,
          uncovered: uncovered,
          uncovered_cost: uncovered_cost,
          plus_one_cost: plus_one_cost,
          total_cost: uncovered_cost + plus_one_cost,
          plus_one: plus_one || false
        }
    end
  end

  defp nights(%Date{} = start_date, %Date{} = end_date), do: Date.diff(end_date, start_date)
  defp nights(_, _), do: nil

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_user={@current_user}
      page_title={@page_title}
    >
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-3xl mx-auto space-y-10">
        <div>
          <h1 class="text-2xl font-semibold leading-6 text-base-content">My Speaker Details</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Please review the speaker agreement, then provide your travel and hotel preferences.
          </p>
        </div>

        <%= if @speaker do %>
          <.contract_section
            approved?={@approved?}
            speaker={@speaker}
            agreement_html={@agreement_html}
          />
          <.travel_section approved?={@approved?} form={@travel_form} />
          <.hotel_section
            approved?={@approved?}
            form={@hotel_form}
            speaker={@speaker}
            summary={@hotel_summary}
          />
        <% else %>
          <div class="bg-warning/10 border border-warning/30 rounded-xl p-6 text-center">
            <p class="text-warning">
              No speaker profile is associated with your account. Please contact the organizers.
            </p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :approved?, :boolean, required: true
  attr :speaker, :any, required: true
  attr :agreement_html, :string, required: true

  defp contract_section(assigns) do
    ~H"""
    <section class="bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6">
      <div class="flex items-baseline justify-between mb-4">
        <h2 class="text-lg font-semibold">1. Speaker Agreement</h2>
        <%= if @approved? do %>
          <span class="badge badge-success">
            Approved {Calendar.strftime(@speaker.contract_approved_at, "%Y-%m-%d %H:%M UTC")}
          </span>
        <% else %>
          <span class="badge badge-warning">Approval required</span>
        <% end %>
      </div>

      <div class="border border-base-300 rounded-lg p-6 sm:p-8 bg-base-100 max-h-[36rem] overflow-y-auto shadow-inner">
        {Phoenix.HTML.raw(@agreement_html)}
      </div>

      <%= if @approved? do %>
        <p class="mt-4 text-sm text-base-content/70">
          You approved this agreement on <strong>{Calendar.strftime(@speaker.contract_approved_at, "%Y-%m-%d at %H:%M UTC")}</strong>.
        </p>
      <% else %>
        <div class="mt-4 flex justify-end">
          <button
            type="button"
            phx-click="approve_contract"
            data-confirm="By clicking Approve you accept the terms above. This is recorded with a timestamp and the system revision."
            class="btn btn-primary"
          >
            I approve the agreement
          </button>
        </div>
      <% end %>
    </section>
    """
  end

  attr :approved?, :boolean, required: true
  attr :form, :any, required: true

  defp travel_section(assigns) do
    ~H"""
    <section class={[
      "bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6",
      not @approved? && "opacity-60"
    ]}>
      <div class="flex items-baseline justify-between mb-2">
        <h2 class="text-lg font-semibold">2. Travel Details</h2>
        <%= if not @approved? do %>
          <span class="badge badge-ghost">Locked until agreement approved</span>
        <% end %>
      </div>
      <p class="text-sm text-base-content/70 mb-6">
        Used to inform the hotel about late-evening arrivals and to figure out who is around for activities beyond the conference itself. All fields are optional.
      </p>

      <.form for={@form} id="travel-form" phx-change="validate_travel" phx-submit="save_travel">
        <fieldset disabled={not @approved?} class="space-y-6">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <.input field={@form[:arrival_date]} type="date" label="Arrival Date" />
            <.input field={@form[:arrival_time]} type="time" label="Arrival Time" />
            <.input field={@form[:leaving_date]} type="date" label="Departure Date" />
            <.input field={@form[:leaving_time]} type="time" label="Departure Time" />
          </div>

          <div class="flex justify-end">
            <.button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
              Save Travel Details
            </.button>
          </div>
        </fieldset>
      </.form>
    </section>
    """
  end

  attr :approved?, :boolean, required: true
  attr :form, :any, required: true
  attr :speaker, :any, required: true
  attr :summary, :any, required: true

  defp hotel_section(assigns) do
    ~H"""
    <section class={[
      "bg-base-100 shadow-sm ring-1 ring-base-content/5 rounded-xl p-6",
      not @approved? && "opacity-60"
    ]}>
      <div class="flex items-baseline justify-between mb-2">
        <h2 class="text-lg font-semibold">3. Speaker Hotel Booking</h2>
        <%= if not @approved? do %>
          <span class="badge badge-ghost">Locked until agreement approved</span>
        <% end %>
      </div>
      <p class="text-sm text-base-content/70 mb-2">
        Tell us how long you would like us to book a room at the speaker hotel.
        We cover up to <strong>{@speaker.days_covered || 3} nights</strong>; anything beyond that is settled by you directly with the hotel.
      </p>
      <p class="text-sm text-base-content/70 mb-6">
        If your needs don't quite fit the form — odd dates, unusual setup, anything else — pick something close and reach out to the organizer. We're quite flexible.
      </p>

      <.form for={@form} id="hotel-form" phx-change="validate_hotel" phx-submit="save_hotel">
        <fieldset disabled={not @approved?} class="space-y-6">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <.input field={@form[:hotel_stay_start_date]} type="date" label="Check-in" />
            <.input field={@form[:hotel_stay_end_date]} type="date" label="Check-out" />
          </div>

          <.input
            field={@form[:plus_one]}
            type="checkbox"
            label="I am bringing a plus one"
          />

          <.input
            field={@form[:special_requests]}
            type="textarea"
            label="Special note for the organizer"
            rows="3"
            placeholder="Dietary restrictions, accessibility needs, anything else we should know"
          />

          <.booking_summary summary={@summary} />

          <div class="flex justify-end">
            <.button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
              Save Hotel Request
            </.button>
          </div>
        </fieldset>
      </.form>
    </section>
    """
  end

  attr :summary, :any, required: true

  defp booking_summary(assigns) do
    ~H"""
    <div class="bg-base-200/40 border border-base-300 rounded-lg p-4 text-sm">
      <%= cond do %>
        <% is_nil(@summary.nights) -> %>
          <p class="text-base-content/60">
            Pick a check-in and check-out date to see coverage and estimated cost.
          </p>
        <% Map.get(@summary, :invalid) -> %>
          <p class="text-error">Check-out must be after check-in.</p>
        <% true -> %>
          <div class="grid grid-cols-2 gap-y-1">
            <span>Nights requested</span>
            <span class="text-right font-mono">{@summary.nights}</span>

            <span>Nights covered by Goatmire</span>
            <span class="text-right font-mono">{min(@summary.nights, @summary.covered)}</span>

            <span>Nights you cover</span>
            <span class={["text-right font-mono", @summary.uncovered > 0 && "text-warning"]}>
              {@summary.uncovered}
            </span>

            <%= if @summary.uncovered > 0 do %>
              <span>Uncovered nights × 1500 SEK</span>
              <span class="text-right font-mono">{@summary.uncovered_cost} SEK</span>
            <% end %>

            <%= if @summary.plus_one do %>
              <span>Plus one ({@summary.nights} × 200 SEK)</span>
              <span class="text-right font-mono">{@summary.plus_one_cost} SEK</span>
            <% end %>

            <span class="font-semibold pt-2 border-t border-base-300 mt-2">Estimated bill</span>
            <span class="text-right font-mono font-semibold pt-2 border-t border-base-300 mt-2">
              {@summary.total_cost} SEK
            </span>
          </div>
          <p class="mt-3 text-xs text-base-content/60">
            Estimate based on 1500 SEK / night and 200 SEK / night for a plus one. Payment is settled at the hotel.
          </p>
      <% end %>
    </div>
    """
  end

  def handle_event("approve_contract", _params, socket) do
    case Gut.Conference.approve_speaker_contract(socket.assigns.speaker,
           actor: socket.assigns.current_user
         ) do
      {:ok, speaker} ->
        socket =
          socket
          |> assign_speaker(speaker, socket.assigns.current_user)
          |> put_flash(:info, "Agreement approved. Thank you!")

        {:noreply, socket}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not approve agreement: #{inspect(error)}")}
    end
  end

  def handle_event("validate_travel", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.travel_form, params)
    {:noreply, assign(socket, :travel_form, form)}
  end

  def handle_event("save_travel", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.travel_form, params: params) do
      {:ok, speaker} ->
        socket =
          socket
          |> assign_speaker(speaker, socket.assigns.current_user)
          |> put_flash(:info, "Travel details saved")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :travel_form, form)}
    end
  end

  def handle_event("validate_hotel", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.hotel_form, params)

    dates = %{
      hotel_stay_start_date: parse_date(params["hotel_stay_start_date"]),
      hotel_stay_end_date: parse_date(params["hotel_stay_end_date"])
    }

    plus_one = parse_checkbox(params["plus_one"])

    socket =
      socket
      |> assign(:hotel_form, form)
      |> assign_hotel_summary(dates, plus_one)

    {:noreply, socket}
  end

  def handle_event("save_hotel", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.hotel_form, params: params) do
      {:ok, speaker} ->
        socket =
          socket
          |> assign_speaker(speaker, socket.assigns.current_user)
          |> put_flash(:info, "Hotel request saved")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :hotel_form, form)}
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_checkbox("true"), do: true
  defp parse_checkbox(true), do: true
  defp parse_checkbox(_), do: false
end

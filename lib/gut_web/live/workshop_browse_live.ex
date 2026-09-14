defmodule GutWeb.WorkshopBrowseLive do
  use GutWeb, :live_view

  alias Gut.Conference

  on_mount {GutWeb.LiveUserAuth, :live_user_optional}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gut.PubSub, "workshops:changed")
      Phoenix.PubSub.subscribe(Gut.PubSub, "workshop_participations:changed")
      Phoenix.PubSub.subscribe(Gut.PubSub, "workshop_rooms:changed")
    end

    workshops = load_workshops()
    workshops_by_day = group_by_day(workshops)

    {participant, existing_participations, selections} =
      load_existing_registrations(socket.assigns[:current_user])

    can_select = socket.assigns[:current_user] != nil

    socket =
      socket
      |> assign(:page_title, "Browse Workshops")
      |> assign(:workshops, workshops)
      |> assign(:workshops_by_day, workshops_by_day)
      |> assign(:selections, selections)
      |> assign(:participant, participant)
      |> assign(:existing_participations, existing_participations)
      |> assign(:name, participant_name(participant, socket.assigns[:current_user]))
      |> assign(:phone_number, participant_phone(participant))
      |> assign(:submitted, false)
      |> assign(:errors, %{})
      |> assign(:current_scope, nil)
      |> assign(:can_select, can_select)
      |> assign(:magic_link_sent, false)
      |> assign(:login_email, "")
      |> assign(:description_workshop, nil)
      |> assign(:sent_surveys, [])
      |> assign(
        :attendee_surveys,
        load_attendee_surveys(socket.assigns[:current_user], existing_participations, workshops)
      )
      |> assign(
        :attendee_blasts,
        load_attendee_blasts(socket.assigns[:current_user], existing_participations, workshops)
      )

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    description_workshop =
      case params["workshop"] do
        nil ->
          nil

        key ->
          Enum.find(socket.assigns.workshops, &(&1.sessionize_id == key)) ||
            Enum.find(socket.assigns.workshops, &(&1.id == key))
      end

    {:noreply, assign(socket, :description_workshop, description_workshop)}
  end

  defp workshop_link_key(%{sessionize_id: sessionize_id}) when is_binary(sessionize_id),
    do: sessionize_id

  defp workshop_link_key(%{id: id}), do: id

  @public_actor Gut.public_actor()

  defp load_workshops do
    Conference.browse_workshops!(actor: @public_actor)
  end

  defp load_existing_registrations(nil), do: {nil, [], %{}}

  defp load_existing_registrations(user) do
    require Ash.Query

    case Gut.Conference.WorkshopParticipant
         |> Ash.Query.filter(user_id == ^user.id)
         |> Ash.Query.load(:workshop_participations)
         |> Ash.read(actor: @public_actor) do
      {:ok, [participant | _]} ->
        participations = participant.workshop_participations

        selections =
          participations
          |> Enum.reduce(%{}, fn p, acc ->
            workshop =
              Ash.get!(Gut.Conference.Workshop, p.workshop_id, actor: @public_actor)

            if workshop.workshop_timeslot_id do
              Map.put(acc, workshop.workshop_timeslot_id, p.workshop_id)
            else
              acc
            end
          end)

        {participant, participations, selections}

      _ ->
        {nil, [], %{}}
    end
  end

  defp participant_name(nil, nil), do: ""
  defp participant_name(nil, _user), do: ""
  defp participant_name(participant, _), do: participant.name || ""

  defp participant_phone(nil), do: ""
  defp participant_phone(participant), do: participant.phone_number || ""

  defp group_by_day(workshops) do
    workshops
    |> Enum.filter(& &1.workshop_timeslot)
    |> Enum.group_by(fn w -> DateTime.to_date(w.workshop_timeslot.start) end)
    |> Enum.sort_by(fn {date, _} -> date end, Date)
    |> Enum.map(fn {date, ws} ->
      slots =
        ws
        |> Enum.group_by(& &1.workshop_timeslot)
        |> Enum.sort_by(fn {ts, _} -> ts.start end, DateTime)

      counts = %{
        registered: ws |> Enum.map(&(&1.registration_count || 0)) |> Enum.sum(),
        waitlisted: ws |> Enum.map(&(&1.waitlist_count || 0)) |> Enum.sum()
      }

      {date, slots, counts}
    end)
  end

  defp effective_limit(workshop) do
    if workshop.workshop_room do
      min(workshop.limit, workshop.workshop_room.limit)
    else
      workshop.limit
    end
  end

  defp spots_remaining(workshop) do
    effective_limit(workshop) - (workshop.registration_count || 0)
  end

  defp workshop_full?(workshop) do
    spots_remaining(workshop) <= 0
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="px-4 sm:px-6 lg:px-8 py-8 max-w-6xl mx-auto">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-base-content">Workshop Registration</h1>
          <p class="mt-2 text-base-content/60">
            Select one workshop per timeslot and register below. We intend to open more slots as we pin down the details of workshops and the spaces they are held in. If you are on the waitlist for a workshop we'll contact you by email leading up to the event. These all require you to be on site at Campus Varberg in Varberg, Sweden. There will be no recordings or remote dealios. It's going to be legendary though.
          </p>
        </div>

        <%= if @submitted do %>
          <div class="bg-success/10 border border-success/20 rounded-xl p-8 text-center">
            <h2 class="text-2xl font-bold text-success mb-2">Registration Complete!</h2>
            <p class="text-base-content/60">
              Your workshop selections have been saved. You'll receive confirmation at the email provided.
            </p>
            <div :if={@sent_surveys != []} class="mt-6 text-left bg-base-100 rounded-xl p-4">
              <h3 class="font-semibold text-base-content mb-2">One more thing!</h3>
              <p class="text-base-content/60 mb-3">
                The organizers of your selected workshops would like you to answer a survey:
              </p>
              <ul class="space-y-2">
                <li :for={%{survey: survey, workshop: workshop} <- @sent_surveys}>
                  <.link navigate={~p"/surveys/#{survey.id}/respond"} class="link link-primary">
                    Answer the survey for {workshop.name}
                  </.link>
                </li>
              </ul>
            </div>
            <button phx-click="reset" class="btn btn-primary mt-4">
              Modify Selections
            </button>
          </div>
        <% else %>
          <%!-- Updates and surveys for workshops the attendee is signed up for --%>
          <div
            :if={@attendee_surveys != [] or @attendee_blasts != []}
            id="attendee-updates"
            class="bg-base-200 rounded-xl p-6 mb-8"
          >
            <h2 class="text-xl font-semibold text-base-content mb-2">From your workshops</h2>
            <p class="text-base-content/60 mb-3">
              Updates and surveys from the organizers of the workshops you signed up for.
            </p>

            <ul :if={@attendee_surveys != []} id="attendee-surveys" class="space-y-2 mb-4">
              <li
                :for={
                  %{survey: survey, workshop: workshop, answered?: answered?} <- @attendee_surveys
                }
                class="flex items-center gap-2"
              >
                <%= if answered? do %>
                  <.icon name="hero-check-circle" class="size-5 text-success" />
                  <span class="text-base-content/70">
                    Survey for {workshop.name} answered. Thank you!
                  </span>
                <% else %>
                  <.icon name="hero-arrow-right" class="size-5 text-primary" />
                  <.link navigate={~p"/surveys/#{survey.id}/respond"} class="link link-primary">
                    Answer the survey for {workshop.name}
                  </.link>
                <% end %>
              </li>
            </ul>

            <ul :if={@attendee_blasts != []} id="attendee-blasts" class="space-y-2">
              <li
                :for={%{blast: blast, workshop: workshop} <- @attendee_blasts}
                class="flex items-start gap-2"
              >
                <.icon name="hero-envelope" class="size-5 text-primary mt-0.5" />
                <span>
                  <.link navigate={~p"/blasts/#{blast.id}"} class="link link-primary">
                    {blast.title}
                  </.link>
                  <span class="text-sm text-base-content/60">
                    &middot; {workshop.name} &middot; {Calendar.strftime(blast.sent_at, "%b %d")}
                  </span>
                </span>
              </li>
            </ul>
          </div>

          <%!-- Top section: login prompt for unauthenticated users --%>
          <%= if !@current_user do %>
            <div class="bg-base-200 rounded-xl p-6 mb-8">
              <%= if @magic_link_sent do %>
                <div class="text-center">
                  <h2 class="text-xl font-semibold text-success mb-2">Check your email!</h2>
                  <p class="text-base-content/60">
                    We've sent a login link to your email address.
                    Click the link in the email to sign in, then come back here to select your workshops.
                  </p>
                </div>
              <% else %>
                <h2 class="text-xl font-semibold text-base-content mb-2">
                  Sign in to register for workshops
                </h2>
                <p class="text-base-content/60 mb-4">
                  Enter your email to receive a login link. Once signed in, you can select workshops below.
                </p>
                <form phx-submit="request_magic_link" class="flex gap-3 items-end max-w-lg">
                  <div class="flex-1">
                    <label class="label" for="login_email">
                      <span class="label-text">Email address</span>
                    </label>
                    <input
                      type="email"
                      id="login_email"
                      name="email"
                      value={@login_email}
                      required
                      placeholder="you@example.com"
                      class="input input-bordered w-full"
                    />
                  </div>
                  <button type="submit" class="btn btn-primary">
                    Send login link
                  </button>
                </form>
              <% end %>
            </div>
          <% end %>

          <%!-- Workshop grid --%>
          <%= for {date, slots, counts} <- @workshops_by_day do %>
            <div class="mb-8">
              <div class="flex flex-wrap items-baseline justify-between gap-x-4 mb-4 border-b border-base-300 pb-2">
                <h2 class="text-xl font-semibold text-base-content">
                  {Calendar.strftime(date, "%A, %B %d, %Y")}
                </h2>
                <span class="text-sm text-base-content/60">
                  {counts.registered} registered &middot; {counts.waitlisted} on waitlist
                </span>
              </div>

              <%= for {timeslot, workshops} <- slots do %>
                <div class="mb-6">
                  <div class="flex items-center gap-3 mb-3">
                    <h3 class="text-lg font-medium text-base-content">{timeslot.name}</h3>
                    <span class="text-sm text-base-content/50">
                      {Calendar.strftime(timeslot.start, "%H:%M")} - {Calendar.strftime(
                        timeslot.end,
                        "%H:%M"
                      )}
                    </span>
                  </div>

                  <div class="rounded-2xl border-2 border-base-300 shadow-sm overflow-hidden md:border-0 md:shadow-none md:rounded-none md:grid md:grid-cols-2 lg:grid-cols-3 md:gap-4">
                    <%= for {workshop, idx} <- Enum.with_index(workshops) do %>
                      <.workshop_card
                        workshop={workshop}
                        selected={Map.get(@selections, timeslot.id) == workshop.id}
                        timeslot_id={timeslot.id}
                        can_select={@can_select}
                        last={idx == length(workshops) - 1}
                      />
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <%!-- Bottom section: name/phone form for logged-in users --%>
          <%= if @current_user do %>
            <div class="bg-base-200 rounded-xl p-6 mt-8">
              <h2 class="text-xl font-semibold text-base-content mb-4">Your Information</h2>
              <form
                id="workshop-browse-info-form"
                phx-submit="save"
                phx-change="validate"
                class="space-y-4"
              >
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="label" for="name">
                      <span class="label-text">Name *</span>
                    </label>
                    <input
                      type="text"
                      id="name"
                      name="name"
                      value={@name}
                      required
                      class={[
                        "input input-bordered w-full",
                        @errors[:name] && "input-error"
                      ]}
                    />
                    <p :if={@errors[:name]} class="text-error text-sm mt-1">{@errors[:name]}</p>
                  </div>
                  <div>
                    <label class="label" for="phone_number">
                      <span class="label-text">Phone number (optional)</span>
                    </label>
                    <input
                      type="tel"
                      id="phone_number"
                      name="phone_number"
                      value={@phone_number}
                      class="input input-bordered w-full"
                    />
                    <p class="text-sm text-base-content/50 mt-1">
                      Useful for last-minute attendance changes on the day of the event.
                    </p>
                  </div>
                </div>

                <div class="pt-4">
                  <button
                    type="submit"
                    class="btn btn-primary"
                    disabled={map_size(@selections) == 0 and @existing_participations == []}
                  >
                    <%= if @participant do %>
                      Save Changes
                    <% else %>
                      Register
                    <% end %>
                  </button>
                  <%= if map_size(@selections) == 0 and @existing_participations == [] do %>
                    <span class="text-sm text-base-content/50 ml-3">
                      Select at least one workshop to register.
                    </span>
                  <% end %>
                </div>
              </form>
            </div>
          <% end %>
        <% end %>
        <%= if @description_workshop do %>
          <div class="modal modal-open" phx-window-keydown="close_description" phx-key="Escape">
            <div class="modal-box max-w-2xl">
              <h3 class="text-lg font-bold">{@description_workshop.name}</h3>
              <%= if @description_workshop.speakers && @description_workshop.speakers != [] do %>
                <p class="text-sm text-base-content/70 mt-1">
                  {Enum.map_join(@description_workshop.speakers, ", ", & &1.full_name)}
                </p>
              <% end %>
              <p class="py-4 whitespace-pre-line">{@description_workshop.description}</p>
              <div class="modal-action">
                <button class="btn" phx-click="close_description">Close</button>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="close_description"></div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :workshop, :map, required: true
  attr :selected, :boolean, required: true
  attr :timeslot_id, :string, required: true
  attr :can_select, :boolean, required: true
  attr :last, :boolean, required: true

  defp workshop_card(assigns) do
    assigns =
      assigns
      |> assign(:full, workshop_full?(assigns.workshop))
      |> assign(:remaining, spots_remaining(assigns.workshop))
      |> assign(:limit, effective_limit(assigns.workshop))

    ~H"""
    <div
      class={[
        "bg-base-100 transition-all",
        !@last && "border-b border-base-300 md:border-b-2",
        "md:card md:shadow-sm md:border-2 md:rounded-2xl",
        @can_select && "cursor-pointer",
        if(@selected,
          do: "bg-primary/5 md:bg-transparent md:border-primary md:ring-2 md:ring-primary/20",
          else: "md:border-base-300 md:hover:border-base-content/20"
        ),
        @full && !@selected && "opacity-75"
      ]}
      phx-click={@can_select && "select"}
      phx-value-timeslot_id={@timeslot_id}
      phx-value-workshop_id={@workshop.id}
    >
      <div class="card-body p-4">
        <div class="flex items-start justify-between gap-2">
          <h4 class="card-title text-base">{@workshop.name}</h4>
          <%= if @can_select do %>
            <input
              type="radio"
              name={"slot-#{@timeslot_id}"}
              checked={@selected}
              class="radio radio-primary mt-1"
              phx-click="select"
              phx-value-timeslot_id={@timeslot_id}
              phx-value-workshop_id={@workshop.id}
            />
          <% end %>
        </div>

        <%= if @workshop.speakers && @workshop.speakers != [] do %>
          <div class="text-sm text-base-content/70">
            {Enum.map_join(@workshop.speakers, ", ", & &1.full_name)}
          </div>
        <% end %>

        <%= if @workshop.description do %>
          <p class="text-sm text-base-content/60 line-clamp-2">{@workshop.description}</p>
          <a
            href="#"
            class="text-sm text-primary hover:underline"
            phx-click="show_description"
            phx-value-workshop_id={@workshop.id}
          >
            Read more
          </a>
        <% end %>

        <div class="flex items-center justify-between mt-2">
          <span class={[
            "text-sm font-medium",
            if(@full, do: "text-error", else: "text-success")
          ]}>
            <%= if @full do %>
              Full (waitlist available)
            <% else %>
              {@remaining} seats left
            <% end %>
          </span>

          <%= if @workshop.workshop_room do %>
            <span class="text-xs text-base-content/40">{@workshop.workshop_room.name}</span>
          <% end %>
        </div>

        <%= if !@can_select do %>
          <p class="text-xs text-base-content/40 mt-1">Log in to select</p>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("select", _params, %{assigns: %{can_select: false}} = socket) do
    {:noreply, socket}
  end

  def handle_event(
        "select",
        %{"timeslot_id" => timeslot_id, "workshop_id" => workshop_id},
        socket
      ) do
    selections =
      if Map.get(socket.assigns.selections, timeslot_id) == workshop_id do
        Map.delete(socket.assigns.selections, timeslot_id)
      else
        Map.put(socket.assigns.selections, timeslot_id, workshop_id)
      end

    {:noreply, assign(socket, :selections, selections)}
  end

  def handle_event("show_description", %{"workshop_id" => workshop_id}, socket) do
    workshop = Enum.find(socket.assigns.workshops, &(&1.id == workshop_id))
    key = if workshop, do: workshop_link_key(workshop), else: workshop_id
    {:noreply, push_patch(socket, to: ~p"/workshops/browse?workshop=#{key}")}
  end

  def handle_event("close_description", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/workshops/browse")}
  end

  def handle_event("request_magic_link", %{"email" => email}, socket) do
    email = String.trim(email)

    if email == "" do
      {:noreply, socket}
    else
      # Find or create user with attendee role
      case Gut.Accounts.get_user_by_email(email, actor: Gut.system_actor("workshop_browse")) do
        {:ok, _user} ->
          :ok

        _ ->
          Gut.Accounts.create_user(email, :attendee, actor: Gut.system_actor("workshop_browse"))
      end

      # Request magic link (ignoring errors - don't leak user existence)
      Gut.Accounts.request_magic_link(email, actor: Gut.system_actor("workshop_browse"))

      {:noreply, assign(socket, :magic_link_sent, true)}
    end
  end

  def handle_event("validate", params, socket) do
    errors = validate_params(params)

    socket =
      socket
      |> assign(:name, params["name"] || "")
      |> assign(:phone_number, params["phone_number"] || "")
      |> assign(:errors, errors)

    {:noreply, socket}
  end

  def handle_event("save", _params, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("save", params, socket) do
    name = String.trim(params["name"] || "")
    phone_number = String.trim(params["phone_number"] || "")
    email = to_string(socket.assigns.current_user.email)

    errors = validate_params(params)

    if errors != %{} do
      {:noreply, assign(socket, :errors, errors)}
    else
      case save_registrations(socket, name, email, phone_number) do
        {:ok, _participant} ->
          sent_surveys =
            load_sent_surveys(
              socket.assigns.current_user,
              Map.values(socket.assigns.selections),
              socket.assigns.workshops
            )

          {:noreply,
           socket
           |> assign(:submitted, true)
           |> assign(:sent_surveys, sent_surveys)
           |> put_flash(:info, "Workshop registration saved!")}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    end
  end

  def handle_event("reset", _params, socket) do
    workshops = load_workshops()
    workshops_by_day = group_by_day(workshops)

    {participant, existing_participations, selections} =
      load_existing_registrations(socket.assigns[:current_user])

    socket =
      socket
      |> assign(:workshops, workshops)
      |> assign(:workshops_by_day, workshops_by_day)
      |> assign(:selections, selections)
      |> assign(:participant, participant)
      |> assign(:existing_participations, existing_participations)
      |> assign(:submitted, false)
      |> assign(
        :attendee_surveys,
        load_attendee_surveys(socket.assigns[:current_user], existing_participations, workshops)
      )
      |> assign(
        :attendee_blasts,
        load_attendee_blasts(socket.assigns[:current_user], existing_participations, workshops)
      )

    {:noreply, socket}
  end

  defp validate_params(params) do
    errors = %{}
    name = String.trim(params["name"] || "")
    if name == "", do: Map.put(errors, :name, "Name is required"), else: errors
  end

  # Sent surveys for the workshops the user is signed up for, with a flag
  # for whether they have already responded.
  defp load_attendee_surveys(nil, _participations, _workshops), do: []
  defp load_attendee_surveys(_user, [], _workshops), do: []

  defp load_attendee_surveys(user, participations, workshops) do
    require Ash.Query

    workshop_ids = Enum.map(participations, & &1.workshop_id)

    surveys =
      Gut.Conference.Survey
      |> Ash.Query.filter(workshop_id in ^workshop_ids and status == :sent)
      |> Ash.read!(actor: user)

    answered =
      Gut.Conference.SurveyResponse
      |> Ash.Query.filter(user_id == ^user.id and survey_id in ^Enum.map(surveys, & &1.id))
      |> Ash.read!(actor: user)
      |> MapSet.new(& &1.survey_id)

    for survey <- surveys,
        workshop = Enum.find(workshops, &(&1.id == survey.workshop_id)) do
      %{survey: survey, workshop: workshop, answered?: MapSet.member?(answered, survey.id)}
    end
  end

  # Blasts sent to the workshops the user is signed up for, newest first.
  defp load_attendee_blasts(nil, _participations, _workshops), do: []
  defp load_attendee_blasts(_user, [], _workshops), do: []

  defp load_attendee_blasts(user, participations, workshops) do
    require Ash.Query

    workshop_ids = Enum.map(participations, & &1.workshop_id)

    Gut.Conference.Blast
    |> Ash.Query.filter(workshop_id in ^workshop_ids)
    |> Ash.Query.sort(sent_at: :desc)
    |> Ash.read!(actor: user)
    |> Enum.flat_map(fn blast ->
      case Enum.find(workshops, &(&1.id == blast.workshop_id)) do
        nil -> []
        workshop -> [%{blast: blast, workshop: workshop}]
      end
    end)
  end

  defp load_sent_surveys(_user, [], _workshops), do: []

  defp load_sent_surveys(user, workshop_ids, workshops) do
    require Ash.Query

    Gut.Conference.Survey
    |> Ash.Query.filter(workshop_id in ^workshop_ids and status == :sent)
    |> Ash.read!(actor: user)
    |> Enum.map(fn survey ->
      %{survey: survey, workshop: Enum.find(workshops, &(&1.id == survey.workshop_id))}
    end)
  end

  defp save_registrations(socket, name, email, phone_number) do
    selections = socket.assigns.selections
    existing_participations = socket.assigns.existing_participations

    # Find or create participant
    participant_result =
      case socket.assigns.participant do
        nil ->
          attrs = %{
            name: name,
            phone_number: phone_number,
            email: email,
            user_id: socket.assigns.current_user.id
          }

          Conference.create_workshop_participant(attrs, actor: @public_actor)

        existing ->
          Conference.update_workshop_participant(
            existing,
            %{name: name, phone_number: phone_number},
            actor: @public_actor
          )
      end

    case participant_result do
      {:ok, participant} ->
        # Remove old participations that are no longer selected
        selected_workshop_ids = Map.values(selections) |> MapSet.new()

        for p <- existing_participations,
            not MapSet.member?(selected_workshop_ids, p.workshop_id) do
          Conference.destroy_workshop_participation(p, actor: @public_actor)
        end

        existing_workshop_ids =
          existing_participations |> Enum.map(& &1.workshop_id) |> MapSet.new()

        # Create new participations
        for {_timeslot_id, workshop_id} <- selections,
            not MapSet.member?(existing_workshop_ids, workshop_id) do
          Conference.register_for_workshop(
            %{workshop_id: workshop_id, workshop_participant_id: participant.id},
            actor: @public_actor
          )
        end

        {:ok, participant}

      {:error, error} ->
        {:error, "Failed to save registration: #{inspect(error)}"}
    end
  end

  def handle_info(%{topic: "workshops:changed"}, socket) do
    workshops = load_workshops()
    workshops_by_day = group_by_day(workshops)
    {:noreply, assign(socket, workshops: workshops, workshops_by_day: workshops_by_day)}
  end

  def handle_info(%{topic: "workshop_participations:changed"}, socket) do
    workshops = load_workshops()
    workshops_by_day = group_by_day(workshops)
    {:noreply, assign(socket, workshops: workshops, workshops_by_day: workshops_by_day)}
  end

  def handle_info(%{topic: "workshop_rooms:changed"}, socket) do
    workshops = load_workshops()
    workshops_by_day = group_by_day(workshops)
    {:noreply, assign(socket, workshops: workshops, workshops_by_day: workshops_by_day)}
  end

  # Ignore Swoosh test adapter messages and other unexpected messages
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end

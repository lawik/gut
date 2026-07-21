defmodule GutWeb.SurveyComponents do
  @moduledoc """
  Shared rendering for the attendee-facing survey form.

  Used by both the real respond page and the organizer's preview so the
  preview always matches what attendees actually see.
  """
  use GutWeb, :html

  attr :questions, :list, required: true
  attr :answers, :map, required: true, doc: "current values keyed by question id"
  attr :missing_ids, :list, default: [], doc: "ids of required questions left unanswered"

  def question_fields(assigns) do
    ~H"""
    <div :for={question <- @questions}>
      <div class="flex items-center gap-1">
        <label class="label" for={"question-#{question.id}"}>
          <span class="label-text font-medium">{question.prompt}</span>
        </label>
        <span :if={question.required} class="text-error" title="Required">*</span>
      </div>
      <%= case question.question_type do %>
        <% :single_line -> %>
          <input
            type="text"
            id={"question-#{question.id}"}
            name={"answers[#{question.id}]"}
            value={@answers[question.id]}
            class="input input-bordered w-full"
          />
        <% :multiline -> %>
          <textarea
            id={"question-#{question.id}"}
            name={"answers[#{question.id}]"}
            rows="4"
            class="textarea textarea-bordered w-full"
          >{@answers[question.id]}</textarea>
        <% :select -> %>
          <select
            id={"question-#{question.id}"}
            name={"answers[#{question.id}]"}
            class="select select-bordered w-full"
          >
            <option value="">-- Choose an option --</option>
            <option
              :for={option <- question.options}
              value={option.label}
              selected={@answers[question.id] == option.label}
            >
              {option.label}
            </option>
          </select>
      <% end %>
      <p :if={question.id in @missing_ids} class="text-error text-sm mt-1">
        This question is required.
      </p>
    </div>
    """
  end

  @doc """
  Returns the ids of required questions that have no non-blank answer in the
  given `answers` params map (keyed by question id).
  """
  def missing_required_ids(questions, answers) do
    for question <- questions,
        question.required,
        String.trim(answers[question.id] || "") == "" do
      question.id
    end
  end
end

# Adding this implementation removed my Policy debug information, so nope

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Forbidden.Policy do
  require Logger

  def to_form_error(%Ash.Error.Forbidden.Policy{} = error) do
    Logger.warning("forbidden:\n\n#{Ash.Error.Forbidden.Policy.report(error, help_text?: false)}")
    {:forbidden, "Access denied due to security policy", []}
  end
end

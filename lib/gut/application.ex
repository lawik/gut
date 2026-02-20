defmodule Gut.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        GutWeb.Telemetry,
        Gut.Repo,
        {DNSCluster, query: Application.get_env(:gut, :dns_cluster_query) || :ignore},
        {Oban,
         AshOban.config(
           Application.fetch_env!(:gut, :ash_domains),
           Application.fetch_env!(:gut, Oban)
         )},
        {Phoenix.PubSub, name: Gut.PubSub},
        GutWeb.Endpoint,
        {AshAuthentication.Supervisor, [otp_app: :gut]}
      ] ++ discord_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Gut.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  defp discord_children do
    case Application.get_env(:nostrum, :token) do
      nil -> []
      "" -> []
      _token -> [Gut.Discord.Consumer]
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    GutWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

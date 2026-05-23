defmodule PrefixedIdDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PrefixedIdDemoWeb.Telemetry,
      PrefixedIdDemo.Repo,
      {DNSCluster, query: Application.get_env(:prefixed_id_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PrefixedIdDemo.PubSub},
      # Start a worker by calling: PrefixedIdDemo.Worker.start_link(arg)
      # {PrefixedIdDemo.Worker, arg},
      # Start to serve requests, typically the last entry
      PrefixedIdDemoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PrefixedIdDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PrefixedIdDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

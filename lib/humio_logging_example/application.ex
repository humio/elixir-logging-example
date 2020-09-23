defmodule HumioLoggingExample.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: HumioLoggingExample.ChatStore.Supervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: HumioLoggingExample.ChatStoreBot.SpammerSupervisor, strategy: :one_for_one},
      HumioLoggingExample.ChatStoreBot.Supervisor,
      # Start the Telemetry supervisor
      HumioLoggingExample.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: HumioLoggingExample.PubSub},
      # Start the Endpoint (http/https)
      HumioLoggingExampleWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HumioLoggingExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    HumioLoggingExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

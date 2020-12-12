defmodule T.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      T.Repo,
      # Start the Telemetry supervisor
      TWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: T.PubSub},
      # Start the Endpoint (http/https)
      TWeb.Endpoint
      # Start a worker by calling: T.Worker.start_link(arg)
      # {T.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: T.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    TWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :humio_logging_example, HumioLoggingExampleWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "obZjEyKwQ1vJwiYfidsYGgWbBYEkjPKI8jmdww8gZY7ofXlXHntJPyKrnzpJ8PQi",
  render_errors: [view: HumioLoggingExampleWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: HumioLoggingExample.PubSub,
  live_view: [signing_salt: "gEtct2kl"]

config :logger_json, :backend,
  metadata: :all,
  formatter: HumioLoggingExample.JSONLoggerFormatter
# Configures Elixir's Logger
#
config :logger,
  backends: [LoggerJSON]
#config :logger, :console,
#  format: "$date $time $level $message $metadata \n",
#  metadata: :all

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

# Humio Elixir Logging Example

To start the demo:

  * Run `mix setup`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To ship logs to humio cloud you can use [`vector`](https://vector.dev)

  * Setup a ingest token for your sandbox on [Humio Cloud](https://cloud.humio.com)
	* Export your ingest token in your shell as `HUMIO_INGEST_TOKEN`
  * Start Phoenix endpoint with `mix phx.server | vector`

Vector toml (`/etc/vector/vector.toml`)
```
data_dir = "/var/lib/vector"

[sources.in]
  type = "stdin"

[sinks.humio]
  type = "humio_logs"
  inputs = ["in"]
  healthcheck = true
  host = "https://cloud.humio.com"
  compression = "gzip"
  token = "${HUMIO_INGEST_TOKEN}" # required

  encoding.codec = "json"

[sinks.out]
  inputs   = ["in"]
  type     = "console"
  encoding = "text"
```

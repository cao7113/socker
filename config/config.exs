import Config

# :error | :info | :debug | :trace
config :socker, :kland_log_level, :error

case config_env() do
  :dev ->
    config :socker, :kland_log_level, :trace

    config :socker, :kland_opts,
      # handler_module: Socker.EchoHandler,
      handler_module: Socker.HTTPHelloWorld,
      transport_module: ThousandIsland.Transports.SSL,
      transport_options: [
        send_timeout: 300_000,
        certfile: Path.join(__DIR__, "../keys/test/server.crt"),
        keyfile: Path.join(__DIR__, "../keys/test/dev.key")
      ]

  _ ->
    config :socker, :kland_opts, port: 0
end

{:ok, _} = Application.ensure_all_started(:browsergrid)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Browsergrid.Repo, :manual)

# Ensure Mock is available
case Code.ensure_loaded(Mock) do
  {:module, Mock} -> :ok
  {:error, :nofile} ->
    Mix.raise """
    Mock is not available. Add to your test dependencies:

    {:mock, "~> 0.3.0", only: :test}
    """
end

# Configure ExUnit
ExUnit.configure(
  exclude: [skip: true],
  max_cases: System.schedulers_online(),
  timeout: 30_000
)

# Disable logging during tests unless specifically enabled
unless System.get_env("LOG_LEVEL") do
  Logger.configure(level: :warning)
end

# Create test media directory
File.mkdir_p!("/tmp/browsergrid-test-media")

# Ensure clean shutdown
System.at_exit(fn _ ->
  File.rm_rf("/tmp/browsergrid-test-media")
end)

defmodule Browsergrid.SessionRuntime.SupportProcess do
  @moduledoc """
  Manages auxiliary processes (e.g. Xvfb, x11vnc, noVNC) associated with a
  browser session.
  """

  require Logger

  @type t :: %{
          name: atom() | String.t(),
          mode: :stub | :command,
          pid: pid(),
          ref: reference() | nil
        }

  @spec start(String.t(), keyword(), map()) :: {:ok, t()} | {:error, term()}
  def start(session_id, config, context) do
    name = Keyword.get(config, :name, :support)
    mode = Keyword.get(config, :mode, :command)

    case mode do
      :stub ->
        pid = spawn_link(fn -> stub_loop() end)
        ref = Process.monitor(pid)
        {:ok, %{name: name, pid: pid, ref: ref, mode: :stub}}

      _ ->
        do_start_command(session_id, name, config, context)
    end
  end

  @spec stop(t()) :: :ok
  def stop(%{mode: :stub, pid: pid, ref: ref}) do
    if Process.alive?(pid), do: Process.exit(pid, :normal)
    if ref, do: Process.demonitor(ref, [:flush])
    :ok
  end

  def stop(%{mode: :command, pid: pid, ref: ref}) do
    if Process.alive?(pid), do: Process.exit(pid, :shutdown)
    if ref, do: Process.demonitor(ref, [:flush])
    :ok
  end

  defp do_start_command(session_id, name, config, context) do
    command = Keyword.get(config, :command)

    if is_nil(command) or command == "" do
      Logger.error("no command configured for support process #{inspect(name)}")
      {:error, :no_command}
    else
      args =
        config
        |> Keyword.get(:args, [])
        |> List.wrap()
        |> Enum.map(&interpolate(&1, context))

      env =
        config
        |> Keyword.get(:env, [])
        |> List.wrap()
        |> Enum.reduce([], fn
          {key, value}, acc -> [{to_string(key), interpolate(value, context)} | acc]
          binary, acc when is_binary(binary) ->
            case String.split(binary, "=", parts: 2) do
              [k, v] -> [{k, interpolate(v, context)} | acc]
              _ -> acc
            end
          _other, acc -> acc
        end)
        |> Enum.reverse()

      cd = Keyword.get(config, :cd)
      muon_opts = maybe_put([stderr_to_stdout: true, env: env], :cd, cd)

      Logger.metadata(session: session_id)
      Logger.info("launching support process #{inspect(name)} command '#{command}' with args #{inspect(args)}")

      case MuonTrap.Daemon.start_link(command, args, muon_opts) do
        {:ok, pid} ->
          ref = Process.monitor(pid)
          Logger.metadata(session: session_id)
          Logger.info("support process #{inspect(name)} spawned pid=#{inspect(pid)} session=#{session_id}")
          {:ok, %{name: name, pid: pid, ref: ref, mode: :command}}

        {:error, reason} ->
          Logger.error("failed to start support process #{inspect(name)}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp interpolate(value, context) when is_binary(value) do
    Enum.reduce(context, value, fn {key, replacement}, acc ->
      String.replace(acc, "{#{key}}", to_string(replacement || ""))
    end)
  end

  defp interpolate(value, _context), do: to_string(value || "")

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: Keyword.put(list, key, value)

  defp stub_loop do
    receive do
      :stop -> :ok
    after
      60_000 -> stub_loop()
    end
  end
end

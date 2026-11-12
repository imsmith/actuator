defmodule Actuator.Transducers.Instances do
  @moduledoc """
  Runs one `ExCpn.Instance` per enabled transducer under a `DynamicSupervisor`,
  registered by transducer name in `Actuator.Transducers.Registry`.
  """

  alias Actuator.Transducers
  alias Actuator.Transducers.Transducer

  @supervisor Actuator.Transducers.InstanceSupervisor
  @registry Actuator.Transducers.Registry

  @doc "Children for the application supervisor: the registry, the dynamic supervisor, and the boot task."
  @spec children() :: [Supervisor.child_spec() | {module, term}]
  def children do
    [
      {Registry, keys: :unique, name: @registry},
      {DynamicSupervisor, name: @supervisor, strategy: :one_for_one},
      Supervisor.child_spec({Task, &boot/0}, id: __MODULE__.Boot, restart: :temporary)
    ]
  end

  @doc "`:via` name for a transducer's instance."
  @spec via(String.t()) :: {:via, Registry, {module, String.t()}}
  def via(name), do: {:via, Registry, {@registry, name}}

  @spec lookup(String.t()) :: pid | nil
  def lookup(name) do
    case Registry.lookup(@registry, name) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc "Starts the instance for a transducer. Already running is `{:ok, pid}` too."
  @spec start(Transducer.t()) :: {:ok, pid} | {:error, term}
  def start(%Transducer{name: name} = t) do
    spec = {ExCpn.Instance, net: Transducer.net(t), name: via(name)}

    case DynamicSupervisor.start_child(@supervisor, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, _} = err -> err
    end
  end

  @doc "Stops the instance. Returns once the registry no longer resolves the name."
  @spec stop(String.t()) :: :ok
  def stop(name) do
    case lookup(name) do
      nil ->
        :ok

      pid ->
        :ok = DynamicSupervisor.terminate_child(@supervisor, pid)
        # The registry unregisters on :DOWN, asynchronously. A call to its partition
        # process orders after that message; the registry has one partition.
        # ponytail: relies on Registry's internal "<name>.PIDPartition0" naming.
        _ = :sys.get_state(Module.concat(@registry, "PIDPartition0"))
        :ok
    end
  end

  @doc "Stops then starts, so a changed definition takes effect. In-flight tokens are lost."
  @spec restart(Transducer.t()) :: {:ok, pid} | {:error, term}
  def restart(%Transducer{} = t) do
    :ok = stop(t.name)
    start(t)
  end

  @doc "Applies a definition's `enabled` flag: start when enabled, stop otherwise."
  @spec sync(Transducer.t()) :: :ok
  def sync(%Transducer{enabled: true} = t) do
    {:ok, _} = restart(t)
    :ok
  end

  def sync(%Transducer{enabled: false, name: name}), do: stop(name)

  @doc "Starts every enabled transducer. Skipped when `:start_transducers` is false (tests)."
  @spec boot() :: :ok
  def boot do
    if Application.get_env(:actuator, :start_transducers, true) do
      Enum.each(Transducers.list_enabled(), &start/1)
    end

    :ok
  end
end

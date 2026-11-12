defmodule Actuator.Transducers.Telemetry do
  @moduledoc """
  `:telemetry` events for transducers.

  | Event | Measurements | Metadata |
  |---|---|---|
  | `[:actuator, :transducer, :fired]` | `%{count: 1}` | `%{transducer, transition}` |
  | `[:actuator, :transducer, :failed]` | `%{count: 1, attempt: n}` | `%{transducer, transition, reason}` |
  | `[:actuator, :listener, :accepted]` | `%{count: 1}` | `%{transducer, place}` |
  | `[:actuator, :listener, :rejected]` | `%{count: 1}` | `%{transducer, reason}` |
  """

  @doc "Emits the event for an `ExCpn.Instance` journal entry."
  @spec journal(String.t(), ExCpn.Instance.event()) :: :ok
  def journal(name, {:fired, transition, _binding, _marking}) do
    :telemetry.execute([:actuator, :transducer, :fired], %{count: 1}, %{
      transducer: name,
      transition: transition
    })
  end

  def journal(name, {:failed, transition, reason, attempt}) do
    :telemetry.execute([:actuator, :transducer, :failed], %{count: 1, attempt: attempt}, %{
      transducer: name,
      transition: transition,
      reason: reason
    })
  end

  @spec listener(:accepted | :rejected, map) :: :ok
  def listener(outcome, metadata) when outcome in [:accepted, :rejected] do
    :telemetry.execute([:actuator, :listener, outcome], %{count: 1}, metadata)
  end
end

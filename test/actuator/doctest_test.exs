defmodule Actuator.DoctestTest do
  use ExUnit.Case, async: true

  alias Actuator.ApiSpecs.ApiSpec
  alias Actuator.Transducers.{ListenerSpec, Transducer}

  doctest ApiSpec
  doctest ListenerSpec
end

defmodule Actuator.Transducers.LayoutTest do
  use ExUnit.Case, async: true
  alias Actuator.Transducers.Layout

  test "ranks a chain left to right and cuts cycles" do
    {:ok, net} =
      ExCpn.parse("""
      cpn-spec 1.0
      place a -type m:n
      place b -type m:n
      place c -type m:n
      transition ab {
        in {a x}
        out {b $x}
      }
      transition bc {
        in {b x}
        out {c $x}
      }
      transition loop {
        in {c x}
        out {a $x}
      }
      transition idle {
        in {c x}
        out {c $x}
      }
      """)

    layout = Layout.compute(net)
    xs = fn id -> layout.nodes[id].x end
    assert xs.({:place, "a"}) < xs.({:transition, "ab"})
    assert xs.({:transition, "ab"}) < xs.({:place, "b"})
    assert xs.({:place, "b"}) < xs.({:transition, "bc"})
    assert xs.({:transition, "bc"}) < xs.({:place, "c"})
    assert map_size(layout.nodes) == 7
    assert length(layout.edges) == 8
    assert layout.width > 0 and layout.height > 0
  end

  test "a net with no sources still lays out" do
    {:ok, net} =
      ExCpn.parse(
        "cpn-spec 1.0\nplace a -type m:n\ntransition t {\n  in {a x}\n  out {a $x}\n}\n"
      )

    layout = Layout.compute(net)
    assert map_size(layout.nodes) == 2
  end
end

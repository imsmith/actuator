defmodule Actuator.TransducersTest do
  use Actuator.DataCase, async: true

  import Actuator.TransducersFixtures
  alias Actuator.Transducers
  alias Actuator.Transducers.Transducer

  test "creates and lists a valid transducer" do
    t = transducer_fixture(%{name: "lights"})
    assert [%Transducer{name: "lights"}] = Transducers.list_transducers()
    assert Transducers.get_by_name("lights").id == t.id
    assert %ExCpn.Net{} = Transducer.net(t)
  end

  test "rejects source that does not parse, with the line" do
    assert {:error, cs} =
             Transducers.create_transducer(%{
               name: "x",
               source: "cpn-spec 1.0\nplace a\n",
               entry_place: "a"
             })

    assert %{source: ["line 2: place 'a' missing -type"]} = errors_on(cs)
  end

  test "rejects source that does not validate" do
    src = "cpn-spec 1.0\nplace a -type m:n\ntransition t {\n  in {ghost x}\n}\n"

    assert {:error, cs} =
             Transducers.create_transducer(%{name: "x", source: src, entry_place: "a"})

    assert %{source: [msg]} = errors_on(cs)
    assert msg =~ "unknown place 'ghost'"
  end

  test "rejects an entry place that is not in the net" do
    assert {:error, cs} =
             Transducers.create_transducer(%{
               name: "x",
               source: valid_source(),
               entry_place: "nowhere"
             })

    assert %{entry_place: ["is not a place in the net"]} = errors_on(cs)
  end

  test "rejects bad names and duplicate names" do
    assert {:error, cs} =
             Transducers.create_transducer(%{
               name: "Bad Name",
               source: valid_source(),
               entry_place: "inbox"
             })

    assert %{name: [_]} = errors_on(cs)
    transducer_fixture(%{name: "dup"})

    assert {:error, cs} =
             Transducers.create_transducer(%{
               name: "dup",
               source: valid_source(),
               entry_place: "inbox"
             })

    assert %{name: ["has already been taken"]} = errors_on(cs)
  end

  test "update, disable, delete" do
    t = transducer_fixture()
    assert {:ok, %{enabled: false}} = Transducers.update_transducer(t, %{enabled: false})
    assert Transducers.list_enabled() == []
    assert {:ok, _} = Transducers.delete_transducer(t)
    assert Transducers.list_transducers() == []
  end
end

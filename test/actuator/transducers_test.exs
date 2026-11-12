defmodule Actuator.TransducersTest do
  use Actuator.DataCase, async: true

  import Actuator.TransducersFixtures
  alias Actuator.Transducers
  alias Actuator.Transducers.{Instances, Transducer}

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

  describe "instances" do
    test "create starts, disable stops, enable restarts, delete stops" do
      t = transducer_fixture()
      on_exit(fn -> Instances.stop(t.name) end)
      assert pid = Instances.lookup(t.name)
      assert ExCpn.Instance.state(Instances.via(t.name)) == :quiescent

      {:ok, t} = Transducers.update_transducer(t, %{enabled: false})
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}
      assert Instances.lookup(t.name) == nil

      {:ok, t} = Transducers.update_transducer(t, %{enabled: true})
      assert Instances.lookup(t.name)

      {:ok, _} = Transducers.delete_transducer(t)
      assert Instances.lookup(t.name) == nil
    end

    test "a changed source takes effect on update" do
      t = transducer_fixture()
      on_exit(fn -> Instances.stop(t.name) end)
      new_source = valid_source() <> "place extra -type m:n\n"
      {:ok, _} = Transducers.update_transducer(t, %{source: new_source})
      assert Map.has_key?(ExCpn.Instance.marking(Instances.via(t.name)), "extra")
    end

    test "boot starts every enabled transducer" do
      a = transducer_fixture(%{enabled: true})
      b = transducer_fixture(%{enabled: false})
      on_exit(fn -> Instances.stop(a.name) end)
      :ok = Instances.stop(a.name)
      Application.put_env(:actuator, :start_transducers, true)
      on_exit(fn -> Application.put_env(:actuator, :start_transducers, false) end)
      :ok = Instances.boot()
      assert Instances.lookup(a.name)
      refute Instances.lookup(b.name)
    end
  end
end

defmodule Actuator.YangModulesTest do
  use Actuator.DataCase, async: true

  import Actuator.YangModulesFixtures
  alias Actuator.YangModules

  test "create reads name and prefix from the source" do
    m = yang_module_fixture()
    assert {m.name, m.prefix} == {"home", "hm"}
  end

  test "create rejects source that does not parse" do
    assert {:error, cs} = YangModules.create_yang_module(%{source: "module { bad"})
    assert %{source: [_]} = errors_on(cs)
  end

  test "resolve passes a net whose place types name stored nodes" do
    yang_module_fixture()

    {:ok, net} =
      ExCpn.parse(
        "cpn-spec 1.0\nyang import home\nplace inbox -type hm:request\nplace lvl -type home:level\n"
      )

    assert YangModules.resolve(net) == []
  end

  test "resolve names missing imports, unknown prefixes, and unknown nodes" do
    yang_module_fixture()

    {:ok, net} =
      ExCpn.parse(
        "cpn-spec 1.0\nyang import home nope\nplace a -type hm:request\nplace b -type hm:other\nplace c -type zz:request\n"
      )

    assert YangModules.resolve(net) == [
             "yang import nope: no stored module with that name",
             "place b: other is not in hm",
             "place c: type zz:request names no imported module"
           ]
  end

  test "resolve skips a net with no imports" do
    {:ok, net} = ExCpn.parse("cpn-spec 1.0\nplace a -type m:request\n")
    assert YangModules.resolve(net) == []
  end

  test "transducer changeset carries resolution errors" do
    yang_module_fixture()

    source =
      "cpn-spec 1.0\nyang import home\nplace inbox -type hm:nope\nplace done -type hm:request\ntransition t {\n  in {inbox r}\n  out {done $r}\n}\n"

    assert {:error, cs} =
             Actuator.Transducers.create_transducer(%{
               name: "x",
               source: source,
               entry_place: "inbox"
             })

    assert %{source: ["place inbox: nope is not in hm"]} = errors_on(cs)
  end
end

defmodule ActuatorWeb.YangModuleLiveTest do
  use ActuatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Actuator.YangModulesFixtures

  setup %{conn: conn} do
    auth = "Basic " <> Base.encode64("admin:dev-token")
    %{conn: put_req_header(conn, "authorization", auth), yang_module: yang_module_fixture()}
  end

  test "lists modules", %{conn: conn, yang_module: m} do
    {:ok, view, _html} = live(conn, ~p"/admin/yang_modules")
    assert has_element?(view, "#yang_modules-#{m.id}", "home")
  end

  test "creates a module from an uploaded file", %{conn: conn, yang_module: m} do
    {:ok, _} = Actuator.YangModules.delete_yang_module(m)
    {:ok, form_live, _html} = live(conn, ~p"/admin/yang_modules/new")

    form_live
    |> file_input("#yang_module-form", :file, [%{name: "home.yang", content: valid_yang()}])
    |> render_upload("home.yang")

    assert has_element?(form_live, "#yang_module_source", "prefix hm")

    {:ok, _, html} =
      form_live
      |> form("#yang_module-form", yang_module: %{source: valid_yang()})
      |> render_submit()
      |> follow_redirect(conn)

    assert html =~ "YANG module created successfully"
  end

  test "show lists place types", %{conn: conn, yang_module: m} do
    {:ok, view, _html} = live(conn, ~p"/admin/yang_modules/#{m}")
    assert has_element?(view, "#node-request", "hm:request")
    assert has_element?(view, "#node-level", "hm:level")
  end

  test "deletes from the index", %{conn: conn, yang_module: m} do
    {:ok, view, _html} = live(conn, ~p"/admin/yang_modules")
    assert view |> element("#yang_modules-#{m.id} a", "Delete") |> render_click()
    refute has_element?(view, "#yang_modules-#{m.id}")
  end
end

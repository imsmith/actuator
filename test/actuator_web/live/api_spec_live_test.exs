defmodule ActuatorWeb.ApiSpecLiveTest do
  use ActuatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Actuator.ApiSpecsFixtures

  @create_attrs %{name: "ping", source: valid_json(), base_url: "http://ping.local"}
  @invalid_attrs %{name: "Bad", source: "{\"swagger\": \"2.0\"}"}

  setup %{conn: conn} do
    auth = "Basic " <> Base.encode64("admin:dev-token")
    %{conn: put_req_header(conn, "authorization", auth), api_spec: api_spec_fixture()}
  end

  test "lists specs with operation counts", %{conn: conn, api_spec: spec} do
    {:ok, view, _} = live(conn, ~p"/admin/api_specs")
    assert has_element?(view, "#api_specs-#{spec.id}", spec.name)
    assert has_element?(view, "#api_specs-#{spec.id} td", "2")
  end

  test "creates a spec after showing validation errors", %{conn: conn} do
    {:ok, index_live, _} = live(conn, ~p"/admin/api_specs")

    {:ok, form_live, _} =
      index_live |> element("a", "New API spec") |> render_click() |> follow_redirect(conn)

    html = form_live |> form("#api_spec-form", api_spec: @invalid_attrs) |> render_change()
    assert html =~ "Swagger 2.0 is not supported"

    {:ok, _, html} =
      form_live
      |> form("#api_spec-form", api_spec: @create_attrs)
      |> render_submit()
      |> follow_redirect(conn)

    assert html =~ "API spec created successfully"
  end

  test "show lists operations", %{conn: conn, api_spec: spec} do
    {:ok, view, _} = live(conn, ~p"/admin/api_specs/#{spec}")
    assert has_element?(view, "#op-setState", "put")
    assert has_element?(view, "#op-listDevices")
  end

  test "deletes from the index", %{conn: conn, api_spec: spec} do
    {:ok, view, _} = live(conn, ~p"/admin/api_specs")
    assert view |> element("#api_specs-#{spec.id} a", "Delete") |> render_click()
    refute has_element?(view, "#api_specs-#{spec.id}")
  end
end

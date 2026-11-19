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
      index_live |> element("header a", "New API spec") |> render_click() |> follow_redirect(conn)

    html = form_live |> form("#api_spec-form", api_spec: @invalid_attrs) |> render_change()
    assert html =~ "Swagger 2.0 is not supported"

    {:ok, _, html} =
      form_live
      |> form("#api_spec-form", api_spec: @create_attrs)
      |> render_submit()
      |> follow_redirect(conn)

    assert html =~ "Created ping."
  end

  test "uploading a file fills source", %{conn: conn} do
    {:ok, form_live, _html} = live(conn, ~p"/admin/api_specs/new")

    form_live
    |> file_input("#api_spec-form", :file, [%{name: "ping.json", content: valid_json()}])
    |> render_upload("ping.json")

    assert has_element?(form_live, "#api_spec_source", "ping")
    assert has_element?(form_live, "#api_spec_name[value=ping]")
  end

  test "show lists operations", %{conn: conn, api_spec: spec} do
    {:ok, view, _} = live(conn, ~p"/admin/api_specs/#{spec}")
    assert has_element?(view, "#op-setState", "put")
    assert has_element?(view, "#op-listDevices")
  end

  test "deletes from the index", %{conn: conn, api_spec: spec} do
    {:ok, view, _} = live(conn, ~p"/admin/api_specs")
    view |> element("#api_specs-#{spec.id} button", "Delete") |> render_click()
    view |> form("#delete-confirm", name: "wrong") |> render_submit()
    assert has_element?(view, "#api_specs-#{spec.id}")
    view |> form("#delete-confirm", name: spec.name) |> render_submit()
    refute has_element?(view, "#api_specs-#{spec.id}")
  end
end

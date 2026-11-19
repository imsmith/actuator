defmodule ActuatorWeb.TransducerLiveTest do
  use ActuatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Actuator.ApiSpecsFixtures
  import Actuator.TransducersFixtures

  alias Actuator.Transducers.Instances

  @create_attrs %{enabled: true, name: "new-one", source: valid_source(), entry_place: "inbox"}
  @update_attrs %{enabled: false, entry_place: "done"}
  @invalid_attrs %{name: "Bad Name", source: "cpn-spec 1.0\nplace a\n", entry_place: "a"}

  setup %{conn: conn} do
    transducer = transducer_fixture()
    on_exit(fn -> Instances.stop(transducer.name) end)
    on_exit(fn -> Instances.stop("new-one") end)
    auth = "Basic " <> Base.encode64("admin:dev-token")
    %{conn: put_req_header(conn, "authorization", auth), transducer: transducer}
  end

  test "admin pages need basic auth", %{transducer: transducer} do
    conn = get(build_conn(), ~p"/admin/transducers/#{transducer}")
    assert conn.status == 401
  end

  describe "Index" do
    test "lists transducers with status", %{conn: conn, transducer: transducer} do
      {:ok, view, _html} = live(conn, ~p"/admin/transducers")
      assert has_element?(view, "#transducers-#{transducer.id}", transducer.name)
      assert has_element?(view, "#transducers-#{transducer.id} [data-role=status]", "quiescent")
    end

    test "saves a new transducer and starts it", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/transducers")

      {:ok, form_live, _} =
        index_live
        |> element("header a", "New transducer")
        |> render_click()
        |> follow_redirect(conn)

      html = form_live |> form("#transducer-form", transducer: @invalid_attrs) |> render_change()
      assert html =~ "line 2: place &#39;a&#39; missing -type"
      assert html =~ "must be lowercase"

      {:ok, _show, html} =
        form_live
        |> form("#transducer-form", transducer: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Created new-one."
      assert Instances.lookup("new-one")
    end

    test "uploading a file fills source and name", %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/admin/transducers/new")

      form_live
      |> file_input("#transducer-form", :file, [%{name: "Lights 2.tcl", content: valid_source()}])
      |> render_upload("Lights 2.tcl")

      assert has_element?(form_live, "#transducer_source", "place inbox")
      assert has_element?(form_live, "#transducer_name[value=lights-2]")
    end

    test "updates and deletes", %{conn: conn, transducer: transducer} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/transducers")

      {:ok, form_live, _} =
        index_live
        |> element("#transducers-#{transducer.id} a", "Edit")
        |> render_click()
        |> follow_redirect(conn)

      {:ok, _, html} =
        form_live
        |> form("#transducer-form", transducer: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Saved #{transducer.name}."
      assert Instances.lookup(transducer.name) == nil

      {:ok, index_live, _html} = live(conn, ~p"/admin/transducers")
      index_live |> element("#transducers-#{transducer.id} button", "Delete") |> render_click()
      assert has_element?(index_live, "#delete-modal", "Delete #{transducer.name}?")
      index_live |> form("#delete-confirm", name: transducer.name) |> render_submit()
      refute has_element?(index_live, "#transducers-#{transducer.id}")
      refute has_element?(index_live, "#delete-modal")
    end
  end

  describe "Show" do
    test "shows the live marking and reacts to tokens", %{conn: conn, transducer: transducer} do
      {:ok, view, _html} = live(conn, ~p"/admin/transducers/#{transducer}")
      assert has_element?(view, "#place-inbox")
      assert has_element?(view, "svg#net-diagram #net-diagram-place-inbox")
      assert has_element?(view, "svg#net-diagram #net-diagram-transition-handle")
      assert has_element?(view, "#marking [data-role=status]", "quiescent")

      view |> form("#inject-form", inject: %{json: ~s({"device":"lamp-1"})}) |> render_submit()
      ExCpn.Instance.await_quiescent(Instances.via(transducer.name))
      # the journal event arrives over PubSub; render after it is processed
      assert render(view) =~ "fired handle"
      assert has_element?(view, "#place-done", "lamp-1")
    end

    test "binds and unbinds a transition", %{conn: conn, transducer: transducer} do
      spec = api_spec_fixture(%{name: "lights"})
      {:ok, view, _html} = live(conn, ~p"/admin/transducers/#{transducer}")
      assert has_element?(view, "#bind-handle")

      view
      |> element("#bind-handle")
      |> render_submit(%{"transition" => "handle", "operation" => "#{spec.id}|setState"})

      assert has_element?(view, "#binding-handle", "lights:setState")
      assert [%{transition: "handle"}] = Actuator.Transducers.list_bindings(transducer)

      view |> element("#binding-handle a", "Unbind") |> render_click()
      assert has_element?(view, "#bind-handle")
      assert Actuator.Transducers.list_bindings(transducer) == []
    end

    test "rejects a non-object token", %{conn: conn, transducer: transducer} do
      {:ok, view, _html} = live(conn, ~p"/admin/transducers/#{transducer}")
      html = view |> form("#inject-form", inject: %{json: "[1,2]"}) |> render_submit()
      assert html =~ "Token must be a JSON object."
    end
  end
end

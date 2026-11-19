defmodule ActuatorWeb.YangModuleLive.Index do
  @moduledoc "Admin list of stored YANG modules."
  use ActuatorWeb, :live_view

  alias Actuator.YangModules

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} section={:yang_modules}>
      <.header>
        YANG modules
        <:subtitle>Place types in a net (<code>prefix:node</code>) resolve against these.</:subtitle>
        <:actions>
          <.button variant={:primary} icon="m-add" navigate={~p"/admin/yang_modules/new"}>
            New YANG module
          </.button>
        </:actions>
      </.header>

      <.table
        id="yang_modules"
        rows={@streams.yang_modules}
        row_click={fn {_id, m} -> JS.navigate(~p"/admin/yang_modules/#{m}") end}
      >
        <:col :let={{_id, m}} label="Module">{m.name}</:col>
        <:col :let={{_id, m}} label="Prefix">{m.prefix}</:col>
        <:action :let={{_id, m}}>
          <.button size={:sm} icon="m-edit" navigate={~p"/admin/yang_modules/#{m}/edit"}>
            Edit
          </.button>
        </:action>
        <:action :let={{_id, m}}>
          <.button
            size={:sm}
            variant={:text}
            icon="m-delete"
            phx-click="confirm-delete"
            phx-value-id={m.id}
          >
            Delete
          </.button>
        </:action>
        <:empty>
          <.state_panel title="No YANG modules.">
            Upload a module so nets can type their places.
            <:action>
              <.button variant={:primary} icon="m-add" navigate={~p"/admin/yang_modules/new"}>
                New YANG module
              </.button>
            </:action>
          </.state_panel>
        </:empty>
      </.table>

      <.delete_modal
        :if={@deleting}
        name={@deleting.name}
        consequence="Nets that import it will fail validation on their next edit."
        typed={@typed}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "YANG modules", deleting: nil, typed: "")
     |> stream(:yang_modules, YangModules.list_yang_modules())}
  end

  @impl true
  def handle_event("confirm-delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, deleting: YangModules.get_yang_module!(id), typed: "")}
  end

  def handle_event("confirm-name", %{"name" => typed}, socket) do
    {:noreply, assign(socket, :typed, typed)}
  end

  def handle_event("cancel-delete", _params, socket) do
    {:noreply, assign(socket, deleting: nil, typed: "")}
  end

  def handle_event(
        "delete",
        %{"name" => name},
        %{assigns: %{deleting: %{name: name} = m}} = socket
      ) do
    {:ok, _} = YangModules.delete_yang_module(m)

    {:noreply,
     socket
     |> assign(deleting: nil, typed: "")
     |> put_flash(:info, "Deleted #{name}.")
     |> stream_delete(:yang_modules, m)}
  end

  def handle_event("delete", _params, socket), do: {:noreply, socket}
end

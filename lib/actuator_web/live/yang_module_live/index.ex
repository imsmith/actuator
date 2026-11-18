defmodule ActuatorWeb.YangModuleLive.Index do
  @moduledoc "Admin list of stored YANG modules."
  use ActuatorWeb, :live_view

  alias Actuator.YangModules

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        YANG modules
        <:subtitle>Place types in a net (<code>prefix:node</code>) resolve against these.</:subtitle>
        <:actions>
          <.button variant="primary" navigate={~p"/admin/yang_modules/new"}>
            <.icon name="hero-plus" /> New YANG module
          </.button>
        </:actions>
      </.header>

      <.table
        id="yang_modules"
        rows={@streams.yang_modules}
        row_click={fn {_id, m} -> JS.navigate(~p"/admin/yang_modules/#{m}") end}
      >
        <:col :let={{_id, m}} label="Module"><span class="font-mono">{m.name}</span></:col>
        <:col :let={{_id, m}} label="Prefix"><span class="font-mono">{m.prefix}</span></:col>
        <:action :let={{_id, m}}>
          <div class="sr-only"><.link navigate={~p"/admin/yang_modules/#{m}"}>Show</.link></div>
          <.link navigate={~p"/admin/yang_modules/#{m}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, m}}>
          <.link
            phx-click={JS.push("delete", value: %{id: m.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "YANG modules")
     |> stream(:yang_modules, YangModules.list_yang_modules())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    m = YangModules.get_yang_module!(id)
    {:ok, _} = YangModules.delete_yang_module(m)
    {:noreply, stream_delete(socket, :yang_modules, m)}
  end
end

defmodule ActuatorWeb.YangModuleLive.Show do
  @moduledoc "Admin view of one YANG module: the names a place type may use, and the source."
  use ActuatorWeb, :live_view

  alias Actuator.YangModules
  alias Actuator.YangModules.YangModule

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} section={:yang_modules}>
      <.breadcrumb items={[
        %{label: "YANG modules", navigate: ~p"/admin/yang_modules"},
        %{label: @yang_module.name}
      ]} />
      <.header>
        {@yang_module.name}
        <:actions>
          <.button
            icon="m-edit"
            navigate={~p"/admin/yang_modules/#{@yang_module}/edit?return_to=show"}
          >
            Edit
          </.button>
        </:actions>
      </.header>

      <.key_value class="mb-6">
        <:item key="Prefix">{@yang_module.prefix}</:item>
        <:item key="Place types">
          <span id="nodes" class="flex flex-wrap gap-2">
            <.tag :for={n <- @nodes} id={"node-#{n}"}>{@yang_module.prefix}:{n}</.tag>
          </span>
        </:item>
      </.key_value>

      <.code_block id="source" title="source · yang" code={@yang_module.source} />
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    m = YangModules.get_yang_module!(id)

    {:ok,
     socket
     |> assign(:page_title, m.name)
     |> assign(:yang_module, m)
     |> assign(:nodes, YangModule.node_names(YangModule.module(m)))}
  end
end

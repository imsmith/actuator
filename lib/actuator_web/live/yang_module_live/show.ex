defmodule ActuatorWeb.YangModuleLive.Show do
  @moduledoc "Admin view of one YANG module: the names a place type may use, and the source."
  use ActuatorWeb, :live_view

  alias Actuator.YangModules
  alias Actuator.YangModules.YangModule

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        <span class="font-mono">{@yang_module.name}</span>
        <:subtitle>Prefix <code>{@yang_module.prefix}</code></:subtitle>
        <:actions>
          <.button navigate={~p"/admin/yang_modules"}><.icon name="hero-arrow-left" /></.button>
          <.button
            variant="primary"
            navigate={~p"/admin/yang_modules/#{@yang_module}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Edit module
          </.button>
        </:actions>
      </.header>

      <section id="nodes" class="space-y-2">
        <h2 class="text-xs font-semibold uppercase tracking-wider text-zinc-500">Place types</h2>
        <ul class="flex flex-wrap gap-2">
          <li
            :for={n <- @nodes}
            id={"node-#{n}"}
            class="rounded bg-zinc-100 px-2 py-1 font-mono text-sm"
          >
            {@yang_module.prefix}:{n}
          </li>
        </ul>
      </section>

      <section id="source" class="space-y-2">
        <h2 class="text-xs font-semibold uppercase tracking-wider text-zinc-500">Source</h2>
        <pre class="text-xs bg-zinc-100 rounded-lg p-4 overflow-x-auto" phx-no-curly-interpolation><%= @yang_module.source %></pre>
      </section>
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

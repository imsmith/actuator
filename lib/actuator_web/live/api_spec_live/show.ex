defmodule ActuatorWeb.ApiSpecLive.Show do
  @moduledoc "Admin view of one API spec: its operations and source."
  use ActuatorWeb, :live_view

  alias Actuator.ApiSpecs

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        <span class="font-mono">{@api_spec.name}</span>
        <:subtitle>
          Calls go to <code>{@api_spec.base_url || "(no base URL)"}</code>
          <span :if={@api_spec.auth_header}>with an Authorization header</span>.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/admin/api_specs"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/api_specs/#{@api_spec}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit api_spec
          </.button>
        </:actions>
      </.header>

      <section id="operations" class="space-y-2">
        <h2 class="text-sm font-semibold uppercase tracking-wide opacity-70">Operations</h2>
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Operation</th>
              <th>Method</th>
              <th>Path</th>
              <th>Summary</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={op <- @operations} id={"op-#{op.id}"}>
              <td class="font-mono">{op.id}</td>
              <td class="font-mono uppercase">{op.method}</td>
              <td class="font-mono">{op.path}</td>
              <td>{op.summary}</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section id="source" class="space-y-2">
        <h2 class="text-sm font-semibold uppercase tracking-wide opacity-70">Source</h2>
        <pre class="text-xs bg-base-200 rounded-lg p-4 overflow-x-auto" phx-no-curly-interpolation><%= @api_spec.source %></pre>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "API spec")
     |> assign(:api_spec, ApiSpecs.get_api_spec!(id))
     |> assign(:operations, ApiSpecs.ApiSpec.operations(ApiSpecs.get_api_spec!(id)))}
  end
end

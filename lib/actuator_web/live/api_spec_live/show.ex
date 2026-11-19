defmodule ActuatorWeb.ApiSpecLive.Show do
  @moduledoc "Admin view of one API spec: its operations and source."
  use ActuatorWeb, :live_view

  alias Actuator.ApiSpecs

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} section={:api_specs}>
      <.breadcrumb items={[
        %{label: "API specs", navigate: ~p"/admin/api_specs"},
        %{label: @api_spec.name}
      ]} />
      <.header>
        {@api_spec.name}
        <:actions>
          <.button icon="m-edit" navigate={~p"/admin/api_specs/#{@api_spec}/edit?return_to=show"}>
            Edit
          </.button>
        </:actions>
      </.header>

      <.key_value class="mb-6">
        <:item key="Base URL">{@api_spec.base_url || "none"}</:item>
        <:item key="Auth header">{if @api_spec.auth_header, do: "set", else: "none"}</:item>
        <:item key="Operations"><span class="ds-data">{length(@operations)}</span></:item>
      </.key_value>

      <.card title="Operations" density={:compact} flush class="mb-6">
        <table class="ds-table ds-table--compact" id="operations">
          <thead>
            <tr>
              <th scope="col" class="ds-table__th">Operation</th>
              <th scope="col" class="ds-table__th">Method</th>
              <th scope="col" class="ds-table__th">Path</th>
              <th scope="col" class="ds-table__th">Summary</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={op <- @operations} id={"op-#{op.id}"} class="ds-table__row">
              <td class="ds-table__td">{op.id}</td>
              <td class="ds-table__td" style="text-transform:uppercase">{op.method}</td>
              <td class="ds-table__td">{op.path}</td>
              <td class="ds-table__td" style="color:var(--muted)">{op.summary}</td>
            </tr>
          </tbody>
        </table>
      </.card>

      <.code_block id="source" title="source · openapi" code={@api_spec.source} />
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    api_spec = ApiSpecs.get_api_spec!(id)

    {:ok,
     socket
     |> assign(:page_title, api_spec.name)
     |> assign(:api_spec, api_spec)
     |> assign(:operations, ApiSpecs.ApiSpec.operations(api_spec))}
  end
end

defmodule ActuatorWeb.ApiSpecLive.Index do
  @moduledoc "Admin list of API specs with operation counts."
  use ActuatorWeb, :live_view

  alias Actuator.ApiSpecs

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        API specs
        <:actions>
          <.button variant="primary" navigate={~p"/admin/api_specs/new"}>
            <.icon name="hero-plus" /> New API spec
          </.button>
        </:actions>
      </.header>

      <.table
        id="api_specs"
        rows={@streams.api_specs}
        row_click={fn {_id, api_spec} -> JS.navigate(~p"/admin/api_specs/#{api_spec}") end}
      >
        <:col :let={{_id, api_spec}} label="Name">
          <span class="font-mono">{api_spec.name}</span>
        </:col>
        <:col :let={{_id, api_spec}} label="Base URL">
          <span class="font-mono text-xs">{api_spec.base_url}</span>
        </:col>
        <:col :let={{_id, api_spec}} label="Operations">{api_spec.operation_count}</:col>
        <:action :let={{_id, api_spec}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/api_specs/#{api_spec}"}>Show</.link>
          </div>
          <.link navigate={~p"/admin/api_specs/#{api_spec}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, api_spec}}>
          <.link
            phx-click={JS.push("delete", value: %{id: api_spec.id}) |> hide("##{id}")}
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
     |> assign(:page_title, "API specs")
     |> stream(:api_specs, list_api_specs())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    api_spec = ApiSpecs.get_api_spec!(id)
    {:ok, _} = ApiSpecs.delete_api_spec(api_spec)

    {:noreply, stream_delete(socket, :api_specs, api_spec)}
  end

  defp list_api_specs do
    Enum.map(ApiSpecs.list_api_specs(), fn s ->
      Map.put(s, :operation_count, length(ApiSpecs.ApiSpec.operations(s)))
    end)
  end
end

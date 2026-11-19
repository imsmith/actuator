defmodule ActuatorWeb.ApiSpecLive.Index do
  @moduledoc "Admin list of API specs with operation counts."
  use ActuatorWeb, :live_view

  alias Actuator.ApiSpecs

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} section={:api_specs}>
      <.header>
        API specs
        <:subtitle>OpenAPI 3 documents for the things behind the gateway.</:subtitle>
        <:actions>
          <.button variant={:primary} icon="m-add" navigate={~p"/admin/api_specs/new"}>
            New API spec
          </.button>
        </:actions>
      </.header>

      <.table
        id="api_specs"
        rows={@streams.api_specs}
        row_click={fn {_id, api_spec} -> JS.navigate(~p"/admin/api_specs/#{api_spec}") end}
      >
        <:col :let={{_id, api_spec}} label="Name">{api_spec.name}</:col>
        <:col :let={{_id, api_spec}} label="Base URL">{api_spec.base_url}</:col>
        <:col :let={{_id, api_spec}} label="Operations">
          <span class="ds-data">{api_spec.operation_count}</span>
        </:col>
        <:action :let={{_id, api_spec}}>
          <.button size={:sm} icon="m-edit" navigate={~p"/admin/api_specs/#{api_spec}/edit"}>
            Edit
          </.button>
        </:action>
        <:action :let={{_id, api_spec}}>
          <.button
            size={:sm}
            variant={:text}
            icon="m-delete"
            phx-click="confirm-delete"
            phx-value-id={api_spec.id}
          >
            Delete
          </.button>
        </:action>
        <:empty>
          <.state_panel title="No API specs.">
            Upload the OpenAPI document of a thing to bind transitions to its operations.
            <:action>
              <.button variant={:primary} icon="m-add" navigate={~p"/admin/api_specs/new"}>
                New API spec
              </.button>
            </:action>
          </.state_panel>
        </:empty>
      </.table>

      <.delete_modal
        :if={@deleting}
        name={@deleting.name}
        consequence="Every binding to its operations is removed."
        typed={@typed}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "API specs", deleting: nil, typed: "")
     |> stream(:api_specs, list_api_specs())}
  end

  @impl true
  def handle_event("confirm-delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, deleting: ApiSpecs.get_api_spec!(id), typed: "")}
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
        %{assigns: %{deleting: %{name: name} = s}} = socket
      ) do
    {:ok, _} = ApiSpecs.delete_api_spec(s)

    {:noreply,
     socket
     |> assign(deleting: nil, typed: "")
     |> put_flash(:info, "Deleted #{name}.")
     |> stream_delete(:api_specs, s)}
  end

  def handle_event("delete", _params, socket), do: {:noreply, socket}

  defp list_api_specs do
    Enum.map(ApiSpecs.list_api_specs(), fn s ->
      Map.put(s, :operation_count, length(ApiSpecs.ApiSpec.operations(s)))
    end)
  end
end

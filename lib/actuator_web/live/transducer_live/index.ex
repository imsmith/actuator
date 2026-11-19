defmodule ActuatorWeb.TransducerLive.Index do
  @moduledoc "Admin list of transducers with each instance's live state."
  use ActuatorWeb, :live_view

  alias Actuator.Transducers
  alias Actuator.Transducers.Instances

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} section={:transducers}>
      <.header>
        Transducers
        <:subtitle>One running net per enabled definition. A row opens the live marking.</:subtitle>
        <:actions>
          <.button variant={:primary} icon="m-add" navigate={~p"/admin/transducers/new"}>
            New transducer
          </.button>
        </:actions>
      </.header>

      <.table
        id="transducers"
        rows={@streams.transducers}
        row_click={fn {_id, transducer} -> JS.navigate(~p"/admin/transducers/#{transducer}") end}
      >
        <:col :let={{_id, transducer}} label="Name">{transducer.name}</:col>
        <:col :let={{_id, transducer}} label="Entry">{transducer.entry_place}</:col>
        <:col :let={{_id, transducer}} label="Listener">POST /t/{transducer.name}</:col>
        <:col :let={{_id, transducer}} label="State">
          <.state_tag state={transducer.state} />
        </:col>
        <:action :let={{_id, transducer}}>
          <.button size={:sm} icon="m-edit" navigate={~p"/admin/transducers/#{transducer}/edit"}>
            Edit
          </.button>
        </:action>
        <:action :let={{_id, transducer}}>
          <.button
            size={:sm}
            variant={:text}
            icon="m-delete"
            phx-click="confirm-delete"
            phx-value-id={transducer.id}
          >
            Delete
          </.button>
        </:action>
        <:empty>
          <.state_panel title="No transducers.">
            Upload a cpn-spec net to create one.
            <:action>
              <.button variant={:primary} icon="m-add" navigate={~p"/admin/transducers/new"}>
                New transducer
              </.button>
            </:action>
          </.state_panel>
        </:empty>
      </.table>

      <.delete_modal
        :if={@deleting}
        name={@deleting.name}
        consequence="Its instance stops and its bindings are removed."
        typed={@typed}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Transducers", deleting: nil, typed: "")
     |> stream(:transducers, list_transducers())}
  end

  @impl true
  def handle_event("confirm-delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, deleting: Transducers.get_transducer!(id), typed: "")}
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
        %{assigns: %{deleting: %{name: name} = t}} = socket
      ) do
    {:ok, _} = Transducers.delete_transducer(t)

    {:noreply,
     socket
     |> assign(deleting: nil, typed: "")
     |> put_flash(:info, "Deleted #{name}.")
     |> stream_delete(:transducers, t)}
  end

  def handle_event("delete", _params, socket), do: {:noreply, socket}

  defp list_transducers do
    Enum.map(Transducers.list_transducers(), fn t ->
      Map.put(t, :state, with(%{state: s} <- Instances.status(t.name), do: s))
    end)
  end
end

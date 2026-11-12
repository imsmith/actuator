defmodule ActuatorWeb.TransducerLive.Index do
  @moduledoc "Admin list of transducers with each instance's live state."
  use ActuatorWeb, :live_view

  alias Actuator.Transducers
  alias Actuator.Transducers.Instances

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Transducers
        <:subtitle>
          Each enabled definition runs as its own net. Click a row for the live marking.
        </:subtitle>
        <:actions>
          <.button variant="primary" navigate={~p"/admin/transducers/new"}>
            <.icon name="hero-plus" /> New Transducer
          </.button>
        </:actions>
      </.header>

      <.table
        id="transducers"
        rows={@streams.transducers}
        row_click={fn {_id, transducer} -> JS.navigate(~p"/admin/transducers/#{transducer}") end}
      >
        <:col :let={{_id, transducer}} label="Name">
          <span class="font-mono">{transducer.name}</span>
        </:col>
        <:col :let={{_id, transducer}} label="Entry place">
          <span class="font-mono">{transducer.entry_place}</span>
        </:col>
        <:col :let={{_id, transducer}} label="Listener">
          <span class="font-mono text-xs">POST /t/{transducer.name}</span>
        </:col>
        <:col :let={{_id, transducer}} label="Status">
          <.status_badge state={transducer.state} />
        </:col>
        <:action :let={{_id, transducer}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/transducers/#{transducer}"}>Show</.link>
          </div>
          <.link navigate={~p"/admin/transducers/#{transducer}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, transducer}}>
          <.link
            phx-click={JS.push("delete", value: %{id: transducer.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  attr :state, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      @state == :quiescent && "badge-success",
      @state == :busy && "badge-warning",
      @state == :running && "badge-info",
      @state == nil && "badge-ghost"
    ]}>
      {@state || "stopped"}
    </span>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Transducers")
     |> stream(:transducers, list_transducers())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    transducer = Transducers.get_transducer!(id)
    {:ok, _} = Transducers.delete_transducer(transducer)

    {:noreply, stream_delete(socket, :transducers, transducer)}
  end

  defp list_transducers do
    Enum.map(Transducers.list_transducers(), fn t ->
      Map.put(t, :state, with(%{state: s} <- Instances.status(t.name), do: s))
    end)
  end
end

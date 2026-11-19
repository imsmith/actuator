defmodule ActuatorWeb.ListenerDocLive do
  @moduledoc "Admin page: how to call each transducer, with the OpenAPI document link."
  use ActuatorWeb, :live_view

  alias Actuator.Transducers
  alias Actuator.Transducers.ListenerSpec

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} section={:listener}>
      <.header>
        Listener API
        <:subtitle>
          Every enabled transducer is one POST. Machine form: <a
            id="openapi-link"
            href={~p"/t/openapi.json"}
            class="ds-link"
          >/t/openapi.json</a>,
          bearer token.
        </:subtitle>
      </.header>

      <.state_panel :if={@transducers == []} title="No enabled transducers.">
        Enable a transducer and its endpoint appears here.
        <:action>
          <.button variant={:primary} navigate={~p"/admin/transducers"}>Transducers</.button>
        </:action>
      </.state_panel>

      <.card :for={t <- @transducers} id={"doc-#{t.name}"} density={:compact} class="mb-4">
        <:actions><.state_tag state={t.state} /></:actions>
        <h2 class="ds-label mb-2">POST /t/{t.name}</h2>
        <.key_value density={:dense} class="mb-2">
          <:item key="Body">one token on {t.entry_place}</:item>
          <:item key="Reply">202 · the place name</:item>
        </.key_value>
        <.code_block id={"curl-#{t.name}"} title="curl">
          {ListenerSpec.curl(t, @base_url)}
        </.code_block>
      </.card>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    transducers =
      Enum.map(Transducers.list_enabled(), fn t ->
        Map.put(t, :state, with(%{state: s} <- Transducers.Instances.status(t.name), do: s))
      end)

    {:ok,
     socket
     |> assign(:page_title, "Listener API")
     |> assign(:base_url, ActuatorWeb.Endpoint.url())
     |> assign(:transducers, transducers)}
  end
end

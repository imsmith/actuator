defmodule ActuatorWeb.ListenerDocLive do
  @moduledoc "Admin page: how to call each transducer, with the OpenAPI document link."
  use ActuatorWeb, :live_view

  alias Actuator.Transducers
  alias Actuator.Transducers.ListenerSpec

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listener API
        <:subtitle>
          Every enabled transducer is a <code>POST</code>
          endpoint. The machine-readable form is
          <a id="openapi-link" href={~p"/t/openapi.json"} class="link font-mono">/t/openapi.json</a>
          (bearer token required).
        </:subtitle>
      </.header>

      <p :if={@transducers == []} class="text-sm opacity-70">No enabled transducers yet.</p>

      <section :for={t <- @transducers} id={"doc-#{t.name}"} class="space-y-2">
        <h2 class="font-mono text-base">POST /t/{t.name}</h2>
        <p class="text-sm opacity-70">
          Body becomes one token on <code>{t.entry_place}</code>. Reply is <code>202</code>
          with the place name.
        </p>
        <pre class="text-xs bg-base-200 rounded-lg p-4 overflow-x-auto" phx-no-curly-interpolation><%= ListenerSpec.curl(t, @base_url) %></pre>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listener API")
     |> assign(:base_url, ActuatorWeb.Endpoint.url())
     |> assign(:transducers, Transducers.list_enabled())}
  end
end

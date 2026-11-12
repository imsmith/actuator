defmodule ActuatorWeb.TransducerLive.Show do
  use ActuatorWeb, :live_view

  alias Actuator.Transducers
  alias Actuator.Transducers.Instances

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        <span class="font-mono">{@transducer.name}</span>
        <:subtitle>
          Listener <code>POST /t/{@transducer.name}</code>
          puts the body on <code>{@transducer.entry_place}</code>.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/admin/transducers"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            variant="primary"
            navigate={~p"/admin/transducers/#{@transducer}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Edit
          </.button>
        </:actions>
      </.header>

      <section id="marking" class="space-y-2">
        <h2 class="text-sm font-semibold uppercase tracking-wide opacity-70">
          Marking <span :if={@status} class="badge badge-sm ml-2">{@status.state}</span>
          <span :if={!@status} class="badge badge-sm badge-ghost ml-2">stopped</span>
        </h2>
        <table :if={@status} class="table table-sm">
          <thead>
            <tr>
              <th>Place</th>
              <th>Tokens</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{place, tokens} <- Enum.sort(@status.marking)} id={"place-#{place}"}>
              <td class="font-mono">{place}</td>
              <td class="font-mono text-xs">
                <span :if={tokens == []} class="opacity-40">—</span>
                <div :for={token <- tokens}>{Jason.encode!(token)}</div>
              </td>
            </tr>
          </tbody>
        </table>
        <p :if={!@status} class="text-sm opacity-70">
          Not running. Enable the transducer to start it.
        </p>
      </section>

      <section id="events" class="space-y-2">
        <h2 class="text-sm font-semibold uppercase tracking-wide opacity-70">Recent events</h2>
        <ul id="event-list" phx-update="stream" class="font-mono text-xs space-y-1">
          <li :for={{id, ev} <- @streams.events} id={id} class={ev.kind == :failed && "text-error"}>
            {ev.text}
          </li>
        </ul>
      </section>

      <section :if={@status} id="inject" class="space-y-2">
        <h2 class="text-sm font-semibold uppercase tracking-wide opacity-70">Inject a token</h2>
        <.form for={@inject} id="inject-form" phx-submit="inject" class="flex gap-2 items-start">
          <.input
            field={@inject[:json]}
            type="text"
            placeholder={~s({"device": "lamp-1"})}
            class="input font-mono text-sm w-full"
          />
          <.button variant="primary">Put on {@transducer.entry_place}</.button>
        </.form>
      </section>

      <section id="source" class="space-y-2">
        <h2 class="text-sm font-semibold uppercase tracking-wide opacity-70">Source</h2>
        <pre class="text-xs bg-base-200 rounded-lg p-4 overflow-x-auto" phx-no-curly-interpolation>{@transducer.source}</pre>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    transducer = Transducers.get_transducer!(id)

    if connected?(socket),
      do: Phoenix.PubSub.subscribe(Actuator.PubSub, Instances.topic(transducer.name))

    {:ok,
     socket
     |> assign(:page_title, transducer.name)
     |> assign(:transducer, transducer)
     |> assign(:status, Instances.status(transducer.name))
     |> assign(:inject, to_form(%{"json" => ""}, as: :inject))
     |> stream(:events, [])}
  end

  @impl true
  def handle_event("inject", %{"inject" => %{"json" => json}}, socket) do
    name = socket.assigns.transducer.name

    with {:ok, token} when is_map(token) <- Jason.decode(json),
         pid when is_pid(pid) <- Instances.lookup(name) do
      :ok = ExCpn.Instance.put_token(pid, socket.assigns.transducer.entry_place, token)

      {:noreply,
       socket |> assign(:status, Instances.status(name)) |> put_flash(:info, "Token placed")}
    else
      nil -> {:noreply, put_flash(socket, :error, "Transducer is not running")}
      _ -> {:noreply, put_flash(socket, :error, "Token must be a JSON object")}
    end
  end

  @impl true
  def handle_info({:transducer, name, event}, socket) do
    {:noreply,
     socket
     |> assign(:status, Instances.status(name))
     |> stream_insert(:events, describe(event), at: 0, limit: 50)}
  end

  defp describe({:fired, t, binding, _marking}),
    do: %{
      id: System.unique_integer([:positive]),
      kind: :fired,
      text: "fired #{t} #{Jason.encode!(binding)}"
    }

  defp describe({:failed, t, reason, n}),
    do: %{
      id: System.unique_integer([:positive]),
      kind: :failed,
      text: "failed #{t} (#{n}) #{inspect(reason)}"
    }
end

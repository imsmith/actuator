defmodule ActuatorWeb.TransducerLive.Show do
  @moduledoc """
  Admin view of one transducer: live marking, journal events over PubSub, token
  injection, transition bindings, and the source.
  """
  use ActuatorWeb, :live_view

  alias Actuator.{ApiSpecs, Transducers}
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

      <section id="bindings" class="space-y-2">
        <h2 class="text-sm font-semibold uppercase tracking-wide opacity-70">Bindings</h2>
        <p class="text-sm opacity-70">
          A bound transition performs an API operation when it fires. Unbound transitions move tokens as written.
        </p>
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Transition</th>
              <th>Operation</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={t <- @transitions} id={"binding-#{t.name}"}>
              <td class="font-mono align-top">{t.name}</td>
              <%= if binding = @bindings[t.name] do %>
                <td class="font-mono text-xs">{binding.api_spec.name}:{binding.operation_id}</td>
                <td>
                  <.link phx-click="unbind" phx-value-id={binding.id} data-confirm="Unbind #{t.name}?">Unbind</.link>
                </td>
              <% else %>
                <td colspan="2">
                  <form id={"bind-#{t.name}"} phx-submit="bind" class="flex gap-2 items-center">
                    <input type="hidden" name="transition" value={t.name} />
                    <select name="operation" class="select select-sm font-mono text-xs" required>
                      <option value="">choose an operation</option>
                      <option :for={{label, value} <- @operation_options} value={value}>
                        {label}
                      </option>
                    </select>
                    <.button class="btn btn-sm">Bind</.button>
                  </form>
                </td>
              <% end %>
            </tr>
          </tbody>
        </table>
      </section>

      <section id="source" class="space-y-2">
        <h2 class="text-sm font-semibold uppercase tracking-wide opacity-70">Source</h2>
        <pre class="text-xs bg-base-200 rounded-lg p-4 overflow-x-auto" phx-no-curly-interpolation><%= @transducer.source %></pre>
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
     |> assign(:transitions, Transducers.Transducer.net(transducer).transitions)
     |> assign_bindings(transducer)
     |> stream(:events, [])}
  end

  defp assign_bindings(socket, transducer) do
    socket
    |> assign(:bindings, Map.new(Transducers.list_bindings(transducer), &{&1.transition, &1}))
    |> assign(
      :operation_options,
      for(
        {spec, op} <- ApiSpecs.all_operations(),
        do: {"#{spec.name}:#{op.id}", "#{spec.id}|#{op.id}"}
      )
    )
  end

  @impl true
  def handle_event("bind", %{"transition" => transition, "operation" => operation}, socket) do
    transducer = socket.assigns.transducer

    with [spec_id, op_id] <- String.split(operation, "|", parts: 2),
         spec when not is_nil(spec) <- ApiSpecs.get_api_spec!(spec_id),
         {:ok, _} <- Transducers.bind(transducer, transition, spec, op_id) do
      {:noreply,
       socket
       |> assign_bindings(transducer)
       |> assign(:status, Instances.status(transducer.name))
       |> put_flash(:info, "Bound #{transition}")}
    else
      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, put_flash(socket, :error, "Could not bind: #{inspect(cs.errors)}")}

      _ ->
        {:noreply, put_flash(socket, :error, "Choose an operation")}
    end
  end

  def handle_event("unbind", %{"id" => id}, socket) do
    transducer = socket.assigns.transducer
    binding = Enum.find(Map.values(socket.assigns.bindings), &(to_string(&1.id) == id))
    {:ok, _} = Transducers.unbind(binding)

    {:noreply,
     socket
     |> assign_bindings(transducer)
     |> assign(:status, Instances.status(transducer.name))
     |> put_flash(:info, "Unbound #{binding.transition}")}
  end

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

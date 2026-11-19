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
    <Layouts.app flash={@flash} section={:transducers}>
      <.breadcrumb items={[
        %{label: "Transducers", navigate: ~p"/admin/transducers"},
        %{label: @transducer.name}
      ]} />
      <.header>
        {@transducer.name}
        <:actions>
          <.button icon="m-edit" navigate={~p"/admin/transducers/#{@transducer}/edit?return_to=show"}>
            Edit
          </.button>
        </:actions>
      </.header>

      <.key_value class="mb-6">
        <:item key="Listener">POST /t/{@transducer.name} → {@transducer.entry_place}</:item>
        <:item key="Entry type">{entry_type(@net, @transducer.entry_place)}</:item>
        <:item key="Bindings">
          <span :if={@bindings == %{}} style="color:var(--muted)">none</span>
          <span :for={{t, b} <- @bindings} class="mr-4">{t} → {b.api_spec.name}:{b.operation_id}</span>
        </:item>
      </.key_value>

      <.card id="diagram" title="Net" density={:compact} class="mb-4">
        <.net
          id="net-diagram"
          net={@net}
          marking={(@status && @status.marking) || %{}}
          enabled={enabled_names(@net, @status)}
          bindings={Map.new(@bindings, fn {t, b} -> {t, "#{b.api_spec.name}:#{b.operation_id}"} end)}
        />
        <p class="ds-label mt-2">
          count = tokens held · accent fill = enabled · ⇄ bound to an operation
        </p>
      </.card>

      <div class="mb-4 grid gap-4 lg:grid-cols-2">
        <.card id="marking" density={:compact} flush>
          <:actions><.state_tag state={@status && @status.state} /></:actions>
          <h2 class="ds-label mb-2 px-4">Marking</h2>
          <table :if={@status} class="ds-table ds-table--dense">
            <thead>
              <tr>
                <th scope="col" class="ds-table__th">Place</th>
                <th scope="col" class="ds-table__th">Tokens</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={{place, tokens} <- Enum.sort(@status.marking)}
                id={"place-#{place}"}
                class="ds-table__row"
              >
                <td class="ds-table__td" style="white-space:nowrap">
                  {place} <span class="ds-data" style="color:var(--accent)">{length(tokens)}</span>
                </td>
                <td class="ds-table__td" style="word-break:break-all">
                  <span :if={tokens == []} style="color:var(--muted)">—</span>
                  <div :for={token <- tokens}>{Jason.encode!(token)}</div>
                </td>
              </tr>
            </tbody>
          </table>
          <.state_panel :if={!@status} title="Not running.">
            Enable the transducer to start it.
            <:action>
              <.button navigate={~p"/admin/transducers/#{@transducer}/edit?return_to=show"}>Edit</.button>
            </:action>
          </.state_panel>
        </.card>

        <.card id="events" title="Events" density={:compact} flush>
          <.log_view id="event-log" lines={@events} height="16rem" />
        </.card>
      </div>

      <.card :if={@status} id="inject" title="Inject a token" density={:compact} class="mb-4">
        <.form for={@inject} id="inject-form" phx-submit="inject" class="flex items-end gap-2">
          <div class="grow">
            <.input field={@inject[:json]} type="text" placeholder={~s({"device": "lamp-1"})} />
          </div>
          <.button type="submit" variant={:primary} icon="m-send">Put on {@transducer.entry_place}</.button>
        </.form>
      </.card>

      <.card id="bindings" title="Bindings" density={:compact} flush class="mb-4">
        <p class="px-4 pb-2" style="color:var(--muted);font-size:var(--text-small);margin:0">
          A bound transition performs an API operation when it fires. Unbound transitions move tokens as written.
        </p>
        <table class="ds-table ds-table--compact">
          <thead>
            <tr>
              <th scope="col" class="ds-table__th">Transition</th>
              <th scope="col" class="ds-table__th">Operation</th>
              <th scope="col" class="ds-table__th"><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={t <- @transitions} id={"binding-#{t.name}"} class="ds-table__row">
              <td class="ds-table__td">{t.name}</td>
              <%= if binding = @bindings[t.name] do %>
                <td class="ds-table__td">{binding.api_spec.name}:{binding.operation_id}</td>
                <td class="ds-table__td" style="width:0">
                  <.link phx-click="unbind" phx-value-id={binding.id} class="ds-link">Unbind</.link>
                </td>
              <% else %>
                <td class="ds-table__td" colspan="2">
                  <form id={"bind-#{t.name}"} phx-submit="bind" class="flex items-center gap-2">
                    <input type="hidden" name="transition" value={t.name} />
                    <.input
                      type="select"
                      name="operation"
                      value=""
                      prompt="choose an operation"
                      options={@operation_options}
                      required
                    />
                    <.button type="submit" size={:sm}>Bind</.button>
                  </form>
                </td>
              <% end %>
            </tr>
          </tbody>
        </table>
      </.card>

      <.code_block id="source" title="source · cpn-spec 1.0">{@transducer.source}</.code_block>
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
     |> assign(:net, Transducers.Transducer.net(transducer))
     |> assign(:transitions, Transducers.Transducer.net(transducer).transitions)
     |> assign_bindings(transducer)
     |> assign(:events, [])}
  end

  defp entry_type(net, place) do
    Enum.find_value(net.places, "untyped", fn p -> p.name == place && p.type end)
  end

  defp enabled_names(_net, nil), do: []

  defp enabled_names(net, %{marking: marking}) do
    for {t, _} <- ExCpn.Marking.enabled(net, marking), do: t.name
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

    case String.split(operation, "|", parts: 2) do
      [spec_id, op_id] ->
        spec = ApiSpecs.get_api_spec!(spec_id)

        case Transducers.bind(transducer, transition, spec, op_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign_bindings(transducer)
             |> assign(:status, Instances.status(transducer.name))
             |> put_flash(:info, "Bound #{transition}.")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, put_flash(socket, :error, "Could not bind: #{inspect(cs.errors)}")}
        end

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
     |> put_flash(:info, "Unbound #{binding.transition}.")}
  end

  def handle_event("inject", %{"inject" => %{"json" => json}}, socket) do
    name = socket.assigns.transducer.name

    with {:ok, token} when is_map(token) <- Jason.decode(json),
         pid when is_pid(pid) <- Instances.lookup(name) do
      :ok = ExCpn.Instance.put_token(pid, socket.assigns.transducer.entry_place, token)

      {:noreply,
       socket
       |> assign(:status, Instances.status(name))
       |> put_flash(:info, "Put on #{socket.assigns.transducer.entry_place}.")}
    else
      nil -> {:noreply, put_flash(socket, :error, "Transducer is not running")}
      _ -> {:noreply, put_flash(socket, :error, "Token must be a JSON object.")}
    end
  end

  @impl true
  def handle_info({:transducer, name, event}, socket) do
    {:noreply,
     socket
     |> assign(:status, Instances.status(name))
     |> update(:events, &Enum.take([describe(event) | &1], 50))}
  end

  # ponytail: events are kept in the LiveView, newest first, 50 deep; the
  # journal store replaces this when it exists.
  defp describe({:fired, t, binding, _marking}),
    do: line(:low, "fired #{t} #{Jason.encode!(binding)}")

  defp describe({:failed, t, reason, n}),
    do: line(:critical, "failed #{t} (#{n}) #{inspect(reason)}")

  defp line(severity, msg) do
    %{
      id: System.unique_integer([:positive]),
      ts: Time.utc_now() |> Time.truncate(:second) |> Time.to_string(),
      severity: severity,
      msg: msg
    }
  end
end

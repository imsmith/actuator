defmodule ActuatorWeb.NetDiagram do
  @moduledoc "SVG rendering of a net with its current marking."
  use Phoenix.Component

  alias Actuator.Transducers.Layout

  attr :id, :string, required: true
  attr :net, ExCpn.Net, required: true
  attr :marking, :map, default: %{}
  attr :enabled, :list, default: [], doc: "names of transitions enabled under the marking"
  attr :bindings, :map, default: %{}, doc: "transition name => label of the bound operation"

  @doc "Draws places as circles with token counts, transitions as bars, arcs with arrowheads."
  def net(assigns) do
    layout = Layout.compute(assigns.net)

    assigns =
      assigns
      |> assign(:layout, layout)
      |> assign(:places, Enum.map(assigns.net.places, &{&1, layout.nodes[{:place, &1.name}]}))
      |> assign(
        :transitions,
        Enum.map(assigns.net.transitions, &{&1, layout.nodes[{:transition, &1.name}]})
      )

    ~H"""
    <svg
      id={@id}
      viewBox={"0 0 #{@layout.width} #{@layout.height}"}
      class="w-full max-w-4xl"
      style={"max-height: #{@layout.height}px"}
      role="img"
      aria-label="Petri net"
    >
      <defs>
        <marker
          id={"#{@id}-arrow"}
          viewBox="0 0 10 10"
          refX="10"
          refY="5"
          markerWidth="7"
          markerHeight="7"
          orient="auto-start-reverse"
        >
          <path d="M 0 0 L 10 5 L 0 10 z" class="fill-zinc-400" />
        </marker>
      </defs>

      <line
        :for={{from, to, var} <- @layout.edges}
        x1={trim(@layout.nodes[from], @layout.nodes[to], from).x}
        y1={trim(@layout.nodes[from], @layout.nodes[to], from).y}
        x2={trim(@layout.nodes[to], @layout.nodes[from], to).x}
        y2={trim(@layout.nodes[to], @layout.nodes[from], to).y}
        class="stroke-zinc-400"
        stroke-width="1.5"
        marker-end={"url(##{@id}-arrow)"}
      >
        <title>{var}</title>
      </line>

      <g
        :for={{p, pos} <- @places}
        id={"#{@id}-place-#{p.name}"}
        transform={"translate(#{pos.x},#{pos.y})"}
      >
        <circle
          r="22"
          class={[
            "stroke-zinc-700 stroke-2",
            if(tokens(@marking, p.name) > 0, do: "fill-amber-100", else: "fill-white")
          ]}
        />
        <text
          :if={tokens(@marking, p.name) > 0}
          text-anchor="middle"
          dominant-baseline="central"
          class="fill-zinc-900 font-mono text-base font-semibold"
        >
          {tokens(@marking, p.name)}
        </text>
        <text y="36" text-anchor="middle" class="fill-zinc-700 font-mono text-[11px]">{p.name}</text>
        <title>{p.name} : {p.type}</title>
      </g>

      <g
        :for={{t, pos} <- @transitions}
        id={"#{@id}-transition-#{t.name}"}
        transform={"translate(#{pos.x},#{pos.y})"}
      >
        <rect
          x="-9"
          y="-24"
          width="18"
          height="48"
          rx="2"
          class={[
            "stroke-2",
            t.name in @enabled && "fill-emerald-500 stroke-emerald-700",
            t.name not in @enabled && Map.has_key?(@bindings, t.name) && "fill-sky-200 stroke-sky-700",
            t.name not in @enabled && not Map.has_key?(@bindings, t.name) &&
              "fill-zinc-300 stroke-zinc-700"
          ]}
        />
        <text y="38" text-anchor="middle" class="fill-zinc-700 font-mono text-[11px]">{t.name}</text>
        <text
          :if={@bindings[t.name]}
          y="51"
          text-anchor="middle"
          class="fill-sky-700 font-mono text-[10px]"
        >
          {@bindings[t.name]}
        </text>
        <title>{t.label}</title>
      </g>
    </svg>
    """
  end

  defp tokens(marking, place), do: length(Map.get(marking, place, []))

  # Shorten an arc so it starts and ends at the node border instead of its centre.
  defp trim(%{x: x1, y: y1}, %{x: x2, y: y2}, {kind, _}) do
    r = if kind == :place, do: 24, else: 26
    d = :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
    if d == 0, do: %{x: x1, y: y1}, else: %{x: x1 + (x2 - x1) * r / d, y: y1 + (y2 - y1) * r / d}
  end
end

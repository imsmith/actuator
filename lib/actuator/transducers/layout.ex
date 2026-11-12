defmodule Actuator.Transducers.Layout do
  @moduledoc """
  Positions a net's places and transitions for drawing. Nodes are ranked by
  longest path from the sources, left to right, and stacked within a rank.
  Cycles are cut wherever the depth-first walk first revisits a node.
  """

  alias ExCpn.Net

  @col 170
  @row 84
  @pad_x 70
  @pad_y 48

  @type node_id :: {:place, String.t()} | {:transition, String.t()}
  @type t :: %{
          nodes: %{node_id => %{x: number, y: number}},
          edges: [{node_id, node_id, String.t()}],
          width: number,
          height: number
        }

  @doc "Computes positions for every place and transition, and the arcs between them."
  @spec compute(Net.t()) :: t
  def compute(%Net{} = net) do
    edges =
      for t <- net.transitions,
          arc <- t.in,
          do: {{:place, arc.place}, {:transition, t.name}, arc.expr}

    edges =
      edges ++
        for t <- net.transitions,
            arc <- t.out,
            do: {{:transition, t.name}, {:place, arc.place}, arc.expr}

    ids =
      Enum.map(net.places, &{:place, &1.name}) ++
        Enum.map(net.transitions, &{:transition, &1.name})

    succ = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))
    targets = MapSet.new(edges, &elem(&1, 1))
    sources = Enum.reject(ids, &MapSet.member?(targets, &1))
    sources = if sources == [], do: Enum.take(ids, 1), else: sources

    ranks = Enum.reduce(sources, %{}, fn s, acc -> rank(s, 0, succ, acc, MapSet.new()) end)
    ranks = Enum.reduce(ids, ranks, fn id, acc -> Map.put_new(acc, id, 0) end)

    by_rank = ids |> Enum.group_by(&ranks[&1]) |> Enum.sort()

    nodes =
      for {r, members} <- by_rank, {id, i} <- Enum.with_index(members), into: %{} do
        {id, %{x: @pad_x + r * @col, y: @pad_y + i * @row}}
      end

    width = @pad_x * 2 + (length(by_rank) - 1) * @col

    height =
      @pad_y * 2 +
        (by_rank |> Enum.map(fn {_, m} -> length(m) end) |> Enum.max(fn -> 1 end) |> Kernel.-(1)) *
          @row

    %{nodes: nodes, edges: edges, width: width, height: height}
  end

  defp rank(id, r, succ, acc, path) do
    if MapSet.member?(path, id) or Map.get(acc, id, -1) >= r do
      acc
    else
      acc = Map.put(acc, id, r)
      path = MapSet.put(path, id)
      Enum.reduce(Map.get(succ, id, []), acc, fn next, a -> rank(next, r + 1, succ, a, path) end)
    end
  end
end

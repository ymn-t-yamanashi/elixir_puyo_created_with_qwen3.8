defmodule Puyopuyo.Board do
  @moduledoc """
  盤面ロジック（純粋関数）。

  盤面は **2 列 × 12 行** の行優先フラットリスト（24 セル）。
  添字は `row * 2 + col`。セル値は `nil`（空き）またはぷよ色
  （`:red | :green | :blue | :yellow`）。
  """

  @width 2
  @height 12
  @size @width * @height

  @doc "盤面の幅（列数）"
  def width, do: @width

  @doc "盤面の高さ（行数）"
  def height, do: @height

  @doc "空の盤面（全セル nil の長さ 24 のリスト）"
  def new, do: List.duplicate(nil, @size)

  @doc "座標が盤面内か"
  def in_bounds?(row, col),
    do: row >= 0 and row < @height and col >= 0 and col < @width

  @doc """
  セルの値を返す。範囲外の場合は `:out`。

  iex> Puyopuyo.Board.at(Puyopuyo.Board.new(), 3, 1)
  nil
  iex> Puyopuyo.Board.at(Puyopuyo.Board.new(), 12, 0)
  :out
  """
  def at(board, row, col) do
    if in_bounds?(row, col) do
      Enum.at(board, row * @width + col)
    else
      :out
    end
  end

  @doc "指定セルの値を書き換える（範囲外は無操作）"
  def set(board, row, col, value) do
    if in_bounds?(row, col) do
      List.replace_at(board, row * @width + col, value)
    else
      board
    end
  end

  @doc "ペアが占有する 2 セル `[{row, col}, {row+1, col}]`"
  def pair_cells(%{row: row, col: col}), do: [{row, col}, {row + 1, col}]

  @doc """
  ペア（2 セル）が盤面に収まり、両セルが空きかどうか。

  iex> Puyopuyo.Board.fits_pair?(Puyopuyo.Board.new(), %{color: :red, row: 0, col: 0})
  true
  """
  def fits_pair?(board, pair) do
    pair
    |> pair_cells()
    |> Enum.all?(fn {r, c} -> in_bounds?(r, c) and at(board, r, c) == nil end)
  end

  @doc "ペアを盤面に固定する（2 セルに色を書き込む）"
  def lock(board, %{color: color, row: row, col: col}) do
    board
    |> set(row, col, color)
    |> set(row + 1, col, color)
  end

  @doc """
  重力で落下させる（列ごとに独立して最下部に詰める）。

  iex> b = Puyopuyo.Board.set(Puyopuyo.Board.new(), 0, 0, :blue)
  iex> Puyopuyo.Board.settle(b) |> Puyopuyo.Board.at(11, 0)
  :blue
  iex> Puyopuyo.Board.settle(b) |> Puyopuyo.Board.at(0, 0)
  nil
  """
  def settle(board) do
    Enum.reduce(0..(@width - 1), board, fn col, board ->
      stack =
        for row <- (@height - 1)..0//-1,
            v = at(board, row, col),
            not is_nil(v),
            do: v

      cleared = Enum.reduce(0..(@height - 1), board, fn row, acc -> set(acc, row, col, nil) end)

      Enum.reduce(Enum.with_index(stack), cleared, fn {v, i}, acc ->
        set(acc, @height - 1 - i, col, v)
      end)
    end)
  end

  @doc """
  同じ色の直交連結（上下左右、BFS）による連結成分のリストを返す。

  iex> b = Enum.reduce(8..11, Puyopuyo.Board.new(), fn r, acc -> Puyopuyo.Board.set(acc, r, 0, :red) end)
  iex> b |> Puyopuyo.Board.connected_components() |> Enum.map(&length/1)
  [4]
  """
  def connected_components(board) do
    color_map =
      for row <- 0..(@height - 1),
          col <- 0..(@width - 1),
          v = at(board, row, col),
          not is_nil(v),
          into: %{} do
        {{row, col}, v}
      end

    color_map
    |> Enum.reduce({[], MapSet.new()}, fn {pos, color}, {comps, visited} ->
      if MapSet.member?(visited, pos) do
        {comps, visited}
      else
        comp = bfs(color_map, color, [pos], MapSet.new())
        {[comp | comps], MapSet.union(visited, MapSet.new(comp))}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp bfs(map, color, queue, seen) do
    case queue do
      [] ->
        seen |> MapSet.to_list()

      [pos | rest] ->
        if MapSet.member?(seen, pos) do
          bfs(map, color, rest, seen)
        else
          seen = MapSet.put(seen, pos)
          neighbors =
            for {dr, dc} <- [{-1, 0}, {1, 0}, {0, -1}, {0, 1}],
                pos2 = {elem(pos, 0) + dr, elem(pos, 1) + dc},
                Map.get(map, pos2) == color,
                do: pos2

          bfs(map, color, rest ++ neighbors, seen)
        end
    end
  end

  @doc """
  サイズ 4 以上の連結成分をすべて消去する。

  戻り値は `{新しい盤面, 消したぷよ数}`。

  iex> b = Enum.reduce(8..11, Puyopuyo.Board.new(), fn r, acc -> Puyopuyo.Board.set(acc, r, 0, :red) end)
  iex> {b2, n} = Puyopuyo.Board.clear_groups(b)
  iex> {n, Puyopuyo.Board.at(b2, 8, 0), Puyopuyo.Board.at(b2, 11, 0)}
  {4, nil, nil}
  """
  def clear_groups(board) do
    {board2, count} =
      connected_components(board)
      |> Enum.reduce({board, 0}, fn comp, {b, n} ->
        if length(comp) >= 4 do
          b2 = Enum.reduce(comp, b, fn {r, c}, b -> set(b, r, c, nil) end)
          {b2, n + length(comp)}
        else
          {b, n}
        end
      end)

    {board2, count}
  end
end

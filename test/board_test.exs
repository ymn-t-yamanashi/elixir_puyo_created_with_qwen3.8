defmodule Puyopuyo.BoardTest do
  use ExUnit.Case, async: true

  alias Puyopuyo.Board

  # ---------------------------------------------------------------
  # 2-1 基礎
  # ---------------------------------------------------------------

  test "new/0 は長さ 24 の全 nil リスト" do
    board = Board.new()
    assert length(board) == 24
    assert Enum.all?(board, &is_nil/1)
  end

  test "at/3: 範囲内は値を返し、範囲外は :out" do
    assert Board.at(Board.new(), 3, 1) == nil
    assert Board.at(Board.new(), 12, 0) == :out
    assert Board.at(Board.new(), -1, 0) == :out
    assert Board.at(Board.new(), 0, 2) == :out

    b = Board.set(Board.new(), 5, 1, :red)
    assert Board.at(b, 5, 1) == :red
  end

  test "in_bounds?/2: 0..11 行 / 0..1 列のみ true" do
    for r <- 0..11, c <- 0..1 do
      assert Board.in_bounds?(r, c)
    end

    refute Board.in_bounds?(12, 0)
    refute Board.in_bounds?(0, 2)
    refute Board.in_bounds?(-1, 0)
  end

  test "set/4: 指定セルに書き、それ以外は不変" do
    b = Board.set(Board.new(), 4, 0, :blue)
    assert b |> Board.at(4, 0) == :blue
    assert length(b) == 24

    # 範囲外は無操作
    assert Board.set(b, 99, 0, :red) == b
  end

  # ---------------------------------------------------------------
  # 2-2 ペア
  # ---------------------------------------------------------------

  test "fits_pair?/2: 両セルが空きなら true" do
    assert Board.fits_pair?(Board.new(), %{color: :red, row: 0, col: 0})
    assert Board.fits_pair?(Board.new(), %{color: :red, row: 0, col: 1})
    assert Board.fits_pair?(Board.new(), %{color: :red, row: 10, col: 0})
  end

  test "fits_pair?/2: 1 つでも塞がれれば false" do
    b1 = Board.set(Board.new(), 0, 0, :red)
    refute Board.fits_pair?(b1, %{color: :green, row: 0, col: 0})

    b2 = Board.set(Board.new(), 1, 1, :red)
    refute Board.fits_pair?(b2, %{color: :green, row: 0, col: 1})
  end

  test "fits_pair?/2: row 11（row+1 が越境）なら false" do
    refute Board.fits_pair?(Board.new(), %{color: :red, row: 11, col: 0})
    refute Board.fits_pair?(Board.new(), %{color: :red, row: 11, col: 1})
  end

  # ---------------------------------------------------------------
  # 2-3 連結・消去
  # ---------------------------------------------------------------

  test "connected_components/1: 縦 4 つ同じ色 → 1 つの成分（サイズ 4）" do
    b =
      Enum.reduce(8..11, Board.new(), fn r, acc -> Board.set(acc, r, 0, :red) end)

    assert Board.connected_components(b) |> Enum.map(&length/1) == [4]
  end

  test "connected_components/1: 2x2 → 1 つの成分" do
    b =
      Board.new()
      |> Board.set(10, 0, :green)
      |> Board.set(10, 1, :green)
      |> Board.set(11, 0, :green)
      |> Board.set(11, 1, :green)

    assert Board.connected_components(b) |> Enum.map(&length/1) == [4]
  end

  test "connected_components/1: 対角 4 つ → 孤立した 4 つの成分" do
    b =
      Board.new()
      |> Board.set(8, 0, :blue)
      |> Board.set(9, 1, :blue)
      |> Board.set(10, 0, :blue)
      |> Board.set(11, 1, :blue)

    assert Board.connected_components(b) |> Enum.map(&length/1) |> Enum.sort() == [1, 1, 1, 1]
  end

  test "clear_groups/1: 4 つ連結 → 消去され、消去数 4" do
    b =
      Enum.reduce(8..11, Board.new(), fn r, acc -> Board.set(acc, r, 0, :red) end)

    {b2, n} = Board.clear_groups(b)
    assert n == 4
    for r <- 8..11, do: assert(Board.at(b2, r, 0) == nil)
  end

  test "clear_groups/1: 3 つ連結 → 消去されない" do
    b =
      Enum.reduce(9..11, Board.new(), fn r, acc -> Board.set(acc, r, 0, :red) end)

    {b2, n} = Board.clear_groups(b)
    assert n == 0
    assert b2 == b
  end

  test "clear_groups/1: 2 つの別々の 4 連結が同時に消去される" do
    b =
      Enum.reduce(8..11, Board.new(), fn r, acc ->
        acc
        |> Board.set(r, 0, :red)
        |> Board.set(r, 1, :green)
      end)

    {b2, n} = Board.clear_groups(b)
    assert n == 8
    for r <- 8..11 do
      assert Board.at(b2, r, 0) == nil
      assert Board.at(b2, r, 1) == nil
    end
  end

  # ---------------------------------------------------------------
  # 2-4 重力
  # ---------------------------------------------------------------

  test "settle/1: 空中に浮いたぷよが床まで落ちる" do
    b = Board.new() |> Board.set(3, 0, :blue)
    b2 = Board.settle(b)
    assert Board.at(b2, 11, 0) == :blue
    assert Board.at(b2, 3, 0) == nil
  end

  test "settle/1: 列ごとに独立（横流れしない）" do
    b =
      Board.new()
      |> Board.set(5, 1, :red)
      |> Board.set(7, 0, :green)

    b2 = Board.settle(b)
    assert Board.at(b2, 11, 1) == :red
    assert Board.at(b2, 11, 0) == :green
    assert Board.at(b2, 5, 1) == nil
    assert Board.at(b2, 7, 0) == nil
  end

  test "settle/1: 既に詰まった列は不変" do
    b =
      Enum.reduce(8..11, Board.new(), fn r, acc -> Board.set(acc, r, 0, :yellow) end)

    assert Board.settle(b) == b
  end

  doctest Board
end

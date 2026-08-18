defmodule Puyopuyo.UITest do
  use ExUnit.Case, async: true

  alias Puyopuyo.{Board, Game, UI}

  @red %{color: :red, row: 0, col: 0}

  defp cell(state, row, col), do: Enum.at(Enum.at(UI.display_grid(state), row), col)

  # ---------------------------------------------------------------
  # display_grid/1
  # ---------------------------------------------------------------

  test "display_grid/1: 12 行 × 2 列のグリッド" do
    grid = UI.display_grid(Game.new())
    assert length(grid) == 12
    for row <- grid do
      assert length(row) == 2
    end
  end

  test "display_grid/1: 各セルは {color|nil, kind}" do
    grid = UI.display_grid(Game.new())
    for row <- grid, {c, k} <- row do
      assert is_nil(c) or is_atom(c)
      assert k in [:locked, :ghost, :active]
    end
  end

  test "display_grid/1: アクティブペア 2 セルが :active" do
    state = %{Game.new() | pair: @red}
    assert cell(state, 0, 0) == {:red, :active}
    assert cell(state, 1, 0) == {:red, :active}
  end

  test "display_grid/1: ゴースト 2 セルが :ghost" do
    state = %{Game.new() | pair: @red}
    assert cell(state, 10, 0) == {:red, :ghost}
    assert cell(state, 11, 0) == {:red, :ghost}
  end

  test "display_grid/1: 静止（着地）位置ではゴーストと重複しない（active のみ）" do
    state = %{Game.new() | pair: %{color: :blue, row: 10, col: 1}}
    assert cell(state, 10, 1) == {:blue, :active}
    assert cell(state, 11, 1) == {:blue, :active}
  end

  test "display_grid/1: 固定セルは上書きされない" do
    board = Board.new() |> Board.set(10, 1, :green)
    state = %{Game.new() | board: board, pair: @red}
    assert cell(state, 10, 1) == {:green, :locked}
    assert cell(state, 11, 1) == {nil, :locked}
  end

  test "display_grid/1: ペアが中盤なら active と ghost が別セル" do
    state = %{Game.new() | pair: %{color: :yellow, row: 8, col: 0}}
    assert cell(state, 8, 0) == {:yellow, :active}
    assert cell(state, 9, 0) == {:yellow, :active}
    assert cell(state, 10, 0) == {:yellow, :ghost}
    assert cell(state, 11, 0) == {:yellow, :ghost}
  end

  test "display_grid/1: ゲームオーバー（pair なし）でも盤面のみ表示" do
    board = Board.new() |> Board.set(11, 0, :red)
    state = %{Game.new() | board: board, pair: nil, over: true}
    grid = UI.display_grid(state)
    assert cell(state, 11, 0) == {:red, :locked}
    assert length(grid) == 12
  end

  # ---------------------------------------------------------------
  # apply_gravity/3
  # ---------------------------------------------------------------

  test "apply_gravity/3: 間隔未満なら何も起きない" do
    state = %{Game.new() | pair: @red}
    {state2, last2} = UI.apply_gravity(state, 1000, 1799)
    assert state2 == state
    assert last2 == 1000
  end

  test "apply_gravity/3: 間隔以上なら 1 ティック進み last_tick=now" do
    state = %{Game.new() | pair: @red}
    {state2, last2} = UI.apply_gravity(state, 1000, 1800)
    assert state2.pair.row == 1
    assert last2 == 1800
  end

  test "apply_gravity/3: 3 倍経過しても 1 フレームで 1 ティックのみ" do
    state = %{Game.new() | pair: @red}
    {state2, last2} = UI.apply_gravity(state, 0, 2400)
    assert state2.pair.row == 1
    assert last2 == 2400
  end

  test "apply_gravity/3: 負の絶対時刻でも正しく判定される" do
    state = %{Game.new() | pair: @red}
    {state2, last2} = UI.apply_gravity(state, -1000, -200)
    assert state2.pair.row == 1
    assert last2 == -200
  end

  test "apply_gravity/3: ゲームオーバー中はティックしない" do
    state = %{Game.new() | pair: @red, over: true}
    {state2, last2} = UI.apply_gravity(state, 0, 10_000)
    assert state2 == state
    assert last2 == 0
  end
end

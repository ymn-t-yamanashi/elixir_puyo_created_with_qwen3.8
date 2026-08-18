defmodule Puyopuyo.GameTest do
  use ExUnit.Case, async: true

  alias Puyopuyo.{Board, Game}

  # ---------------------------------------------------------------
  # 3-1 初期化
  # ---------------------------------------------------------------

  test "new/0: ペアが出現、score=0、ゲームオーバーでなく、キュー >= 4" do
    game = Game.new()
    refute game.over
    assert game.score == 0
    assert game.max_chain == 0
    assert game.total_cleared == 0
    assert length(game.queue) >= 4
    assert game.pair != nil
  end

  test "new/0: 出現ペアの 2 セルは空き" do
    game = Game.new()
    assert Board.fits_pair?(game.board, game.pair)
    assert game.pair.row == 0
  end

  # ---------------------------------------------------------------
  # 3-2 移動
  # ---------------------------------------------------------------

  test "move/2: 左右 1 列ずつ動ける" do
    game = Game.new()
    assert Game.move(game, -1).pair.col == 0
    assert Game.move(game, +1).pair.col == 1

    game2 = %{game | pair: %{game.pair | col: 0}}
    assert Game.move(game2, +1).pair.col == 1
  end

  test "move/2: 壁では動かない" do
    game = %{Game.new() | pair: %{color: :red, row: 0, col: 0}}
    assert Game.move(game, -1) == game

    game = %{game | pair: %{game.pair | col: 1}}
    assert Game.move(game, +1) == game
  end

  test "move/2: 障害物が挟まったら動けない" do
    board =
      Board.new()
      |> Board.set(0, 1, :blue)
      |> Board.set(1, 1, :blue)

    game = %{Game.new() | board: board, pair: %{color: :red, row: 0, col: 0}}
    assert Game.move(game, +1) == game
  end

  # ---------------------------------------------------------------
  # 3-3 ドロップ
  # ---------------------------------------------------------------

  test "soft_drop/1: 1 段下がり +1 点" do
    game = %{Game.new() | pair: %{color: :red, row: 0, col: 0}, score: 0}
    game2 = Game.soft_drop(game)
    assert game2.pair.row == 1
    assert game2.score == 1
  end

  test "soft_drop/1: 底で止まっても固定はしない" do
    game = %{Game.new() | pair: %{color: :red, row: 10, col: 0}, score: 5}
    game2 = Game.soft_drop(game)
    assert game2.pair.row == 10
    assert game2.score == 5
    assert game2.board == Board.new()
  end

  test "hard_drop/1: 最下部まで落下し固定、連鎖後に次のペアが出現" do
    game = %{Game.new() | pair: %{color: :red, row: 0, col: 0}, score: 0}
    next_color = hd(game.queue)

    game2 = Game.hard_drop(game)
    assert Board.at(game2.board, 10, 0) == :red
    assert Board.at(game2.board, 11, 0) == :red
    # 落下 10 段 * 2 点
    assert game2.score == 20
    # 次のペアが出現
    assert game2.pair != nil
    assert game2.pair.color == next_color
  end

  test "tick/1: 1 段下がる" do
    game = %{Game.new() | pair: %{color: :red, row: 0, col: 0}}
    assert Game.tick(game).pair.row == 1
  end

  test "tick/1: 着地したら固定される" do
    game = %{Game.new() | pair: %{color: :red, row: 10, col: 0}}
    game2 = Game.tick(game)
    assert Board.at(game2.board, 10, 0) == :red
    assert Board.at(game2.board, 11, 0) == :red
    assert game2.pair != nil # 次のペアが出現
  end

  # ---------------------------------------------------------------
  # 3-4 連鎖・スコア
  # ---------------------------------------------------------------

  test "1 連鎖で 4 消去 → score = 4*10*1 = 40" do
    # 左列に赤 2 つ（10, 11 行）、赤ペアを左列に落とす（着地 8, 9 行）→ 縦 4 連結
    # ハードドロップ 8 段 ×2 = 16 点 ＋ チェーン 40 点
    board =
      Board.new()
      |> Board.set(10, 0, :red)
      |> Board.set(11, 0, :red)

    game = %{Game.new() | board: board, pair: %{color: :red, row: 0, col: 0}, score: 0}
    game2 = Game.hard_drop(game)
    assert game2.total_cleared == 4
    assert game2.max_chain == 1
    assert game2.score == 16 + 40
  end

  test "2 連鎖 → score = 4*10*1 + 4*10*2" do
    # 左列: 赤 2（10, 11）+ 赤ペア落下（8, 9）で 4 消去（連鎖 1）
    # 右列: 赤 2 が浮遊（0, 1）+ 赤 2（6, 7）→ 落下で 4 消去（連鎖 2）
    # （右列の赤は連鎖 1 時、左列の 4 と隣接しない位置に配置する）
    board =
      Board.new()
      |> Board.set(10, 0, :red)
      |> Board.set(11, 0, :red)
      |> Board.set(0, 1, :red)
      |> Board.set(1, 1, :red)
      |> Board.set(6, 1, :red)
      |> Board.set(7, 1, :red)

    game = %{Game.new() | board: board, pair: %{color: :red, row: 0, col: 0}, score: 0}
    game2 = Game.hard_drop(game)
    assert game2.total_cleared == 8
    assert game2.max_chain == 2
    assert game2.score == 16 + 40 + 80
  end

  test "10 個以上の連鎖 → 10ぷよボーナス（10*10*2 = 200）" do
    # 左列に赤 10 つ（0..9 行）。青ペアは右列から落下し連結しない
    board =
      Enum.reduce(0..9, Board.new(), fn r, acc -> Board.set(acc, r, 0, :red) end)

    game = %{Game.new() | board: board, pair: %{color: :blue, row: 0, col: 1}, score: 0}
    game2 = Game.hard_drop(game)
    assert game2.total_cleared == 10
    assert game2.max_chain == 1
    assert game2.score == 20 + 200
  end

  test "chain_score/2 の直接検証" do
    assert Game.chain_score(4, 1) == 40
    assert Game.chain_score(4, 2) == 80
    assert Game.chain_score(10, 1) == 200
    assert Game.chain_score(12, 2) == 480
  end

  # ---------------------------------------------------------------
  # 3-5 ゲームオーバー
  # ---------------------------------------------------------------

  test "上段 2 行が塞がれている → 出現できずゲームオーバー" do
    board =
      Board.new()
      |> Board.set(0, 0, :red)
      |> Board.set(0, 1, :green)
      |> Board.set(1, 0, :red)
      |> Board.set(1, 1, :green)

    game = %{Game.new() | board: board, pair: nil}
    game = Game.spawn_next(game)
    assert Game.over?(game)
    assert game.message == "ゲームオーバー"
    assert game.pair == nil
  end

  test "ゲームオーバー後は move/soft_drop/hard_drop/tick で状態が不変" do
    board =
      Board.new()
      |> Board.set(0, 0, :red)
      |> Board.set(0, 1, :green)
      |> Board.set(1, 0, :red)
      |> Board.set(1, 1, :green)

    game = %{Game.new() | board: board, pair: nil}
    game = Game.spawn_next(game)

    assert Game.move(game, -1) == game
    assert Game.move(game, +1) == game
    assert Game.soft_drop(game) == game
    assert Game.hard_drop(game) == game
    assert Game.tick(game) == game
  end

  # ---------------------------------------------------------------
  # 3-6 補助
  # ---------------------------------------------------------------

  test "ghost_pair/1: 着地位置を返す" do
    game = %{Game.new() | pair: %{color: :red, row: 0, col: 1}}
    ghost = Game.ghost_pair(game)
    assert ghost.row == 10
    assert ghost.col == 1

    assert Game.ghost_pair(%{game | pair: nil}) == nil
  end

  test "next_pairs/1: キュー先頭 3 件を返す" do
    game = Game.new()
    assert Game.next_pairs(game) == Enum.take(game.queue, 3)
    assert length(Game.next_pairs(game)) == 3
  end

  test "空盤面で hard_drop するとペアは最下段 (row 10, 11) に固定される" do
    game = Game.new()
    color = game.pair.color
    col = game.pair.col

    game2 = Game.hard_drop(game)
    assert Board.at(game2.board, 10, col) == color
    assert Board.at(game2.board, 11, col) == color
  end

  test "重力間隔は 800ms" do
    assert Game.gravity_ms() == 800
  end

  doctest Game
end

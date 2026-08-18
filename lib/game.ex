defmodule Puyopuyo.Game do
  @moduledoc """
  ゲーム全体の状態とルール（純粋関数）。

  - ペア（2 セル）を左右移動 / ソフトドロップ / ハードドロップで操作
  - 固定後に「消去 → 落下」を繰り返す（= 連鎖）
  - 連鎖スコア: `消した数 * 10`（10 個以上なら ×2）`* 連鎖数`
  - ソフトドロップ +1/段、ハードドロップ +2/段
  - 次ペアが出現できなければゲームオーバー
  """

  alias Puyopuyo.{Board, Puyo}

  @type t :: %__MODULE__{
          board: [atom() | nil],
          pair: map() | nil,
          queue: [atom()],
          score: non_neg_integer(),
          max_chain: non_neg_integer(),
          total_cleared: non_neg_integer(),
          over: boolean(),
          message: String.t() | nil
        }

  defstruct [
    :board,
    :pair,
    :queue,
    :score,
    :max_chain,
    :total_cleared,
    :over,
    :message
  ]

  @gravity_ms 800

  @doc "重力の間隔（ミリ秒）"
  def gravity_ms, do: @gravity_ms

  @doc "新しいゲームを開始する（1 個目のペアを出現させ済み）"
  def new do
    %__MODULE__{
      board: Board.new(),
      queue: build_bag() ++ build_bag(),
      score: 0,
      max_chain: 0,
      total_cleared: 0,
      over: false,
      message: nil
    }
    |> spawn_next()
  end

  @doc "ゲームオーバーか"
  def over?(%__MODULE__{over: over}), do: over

  @doc "次のペアを出現させる（出現できなければゲームオーバー）"
  def spawn_next(%__MODULE__{over: true} = game), do: game

  def spawn_next(game) do
    [color | rest] = game.queue
    base = %{game | queue: top_up(rest)}

    pair =
      cond do
        Board.fits_pair?(game.board, %{color: color, row: 0, col: 0}) ->
          %{color: color, row: 0, col: 0}

        Board.fits_pair?(game.board, %{color: color, row: 0, col: 1}) ->
          %{color: color, row: 0, col: 1}

        true ->
          nil
      end

    if pair do
      %{base | pair: pair, over: false, message: nil}
    else
      %{base | pair: nil, over: true, message: "ゲームオーバー"}
    end
  end

  @doc "ペアを 1 列動かす（`-1` 左 / `+1` 右）。壁・障害物に阻まれる"
  def move(%__MODULE__{over: true} = game, _dir), do: game

  def move(game, dir) do
    col = game.pair.col + dir

    if col >= 0 and col < Board.width() do
      new_pair = %{game.pair | col: col}

      if Board.fits_pair?(game.board, new_pair) do
        %{game | pair: new_pair}
      else
        game
      end
    else
      game
    end
  end

  @doc "1 段下げる（+1 点）。着地したらそのまま（固定はしない）"
  def soft_drop(%__MODULE__{over: true} = game), do: game

  def soft_drop(game) do
    next = %{game.pair | row: game.pair.row + 1}

    if Board.fits_pair?(game.board, next) do
      %{game | pair: next, score: game.score + 1}
    else
      game
    end
  end

  @doc "最下部まで落下・固定（+2 点/段）。連鎖処理後に次のペアを出現"
  def hard_drop(%__MODULE__{over: true} = game), do: game

  def hard_drop(game) do
    row = drop_row(game, game.pair.row)
    dist = row - game.pair.row

    game
    |> Map.put(:score, game.score + dist * 2)
    |> Map.put(:pair, %{game.pair | row: row})
    |> lock_and_cascade()
  end

  @doc "重力ティック: 1 段下がる。着地したら固定＋連鎖処理"
  def tick(%__MODULE__{over: true} = game), do: game

  def tick(game) do
    next = %{game.pair | row: game.pair.row + 1}

    if Board.fits_pair?(game.board, next) do
      %{game | pair: next}
    else
      lock_and_cascade(game)
    end
  end

  @doc """
  連鎖の得点を計算する。

  `消した数 * 10`（10 個以上なら ×2）`* 連鎖数`

  iex> Puyopuyo.Game.chain_score(4, 1)
  40
  iex> Puyopuyo.Game.chain_score(4, 2)
  80
  iex> Puyopuyo.Game.chain_score(10, 1)
  200
  iex> Puyopuyo.Game.chain_score(12, 2)
  480
  """
  def chain_score(count, chain) when count > 0 and chain > 0 do
    base = count * 10
    base = if count >= 10, do: base * 2, else: base
    base * chain
  end

  @doc "現在のペアの着地予想位置（ゴースト）。ペアがなければ nil"
  def ghost_pair(%__MODULE__{pair: nil}), do: nil

  def ghost_pair(game) do
    row = drop_row(game, game.pair.row)
    %{game.pair | row: row}
  end

  @doc "次の 3 ペアの色"
  def next_pairs(game), do: game.queue |> Enum.take(3)

  # ------------------------------------------------------------------
  # 内部関数
  # ------------------------------------------------------------------

  # ペアがそのまま置ける最も深い row（現在の row から開始）
  defp drop_row(game, row) do
    max_row = Board.height() - 2

    cond do
      row >= max_row ->
        row

      not Board.fits_pair?(game.board, %{game.pair | row: row + 1}) ->
        row

      true ->
        drop_row(game, row + 1)
    end
  end

  # 固定 → 消去/落下の連鎖 → 統計更新 → 次のペア出現
  defp lock_and_cascade(game) do
    board = Board.lock(game.board, game.pair)
    {board2, cleared_counts} = cascade(board, [])

    gained =
      cleared_counts
      |> Enum.reverse()
      |> Enum.with_index(1)
      |> Enum.reduce(0, fn {count, chain}, acc -> acc + chain_score(count, chain) end)

    game
    |> Map.put(:board, board2)
    |> Map.put(:score, game.score + gained)
    |> Map.put(:max_chain, max(game.max_chain, length(cleared_counts)))
    |> Map.put(:total_cleared, game.total_cleared + Enum.sum(cleared_counts))
    |> spawn_next()
  end

  # 消去 → 落下 → 再び消去 … 消去対象がなくなるまで
  defp cascade(board, acc) do
    {board2, count} = Board.clear_groups(board)

    if count == 0 do
      {board2, acc}
    else
      cascade(Board.settle(board2), [count | acc])
    end
  end

  # 4 色 1 組をシャッフルしたバッグ
  defp build_bag, do: Puyo.types() |> Enum.shuffle()

  # キューが 4 個以下なら次のバッグで補充
  defp top_up(queue) do
    if length(queue) <= 4 do
      queue ++ build_bag()
    else
      queue
    end
  end
end

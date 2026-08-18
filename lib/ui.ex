defmodule Puyopuyo.UI do
  @moduledoc """
  ex_ratatui による画面描画とゲームループ。

  操作:
    ← / a    : 左移動
    → / d    : 右移動
    ↓ / s    : ソフトドロップ（+1 点/段）
    Space    : ハードドロップ（+2 点/段）
    r        : リスタート
    q        : 終了
  """

  alias ExRatatui
  alias ExRatatui.Event
  alias ExRatatui.Style
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Widgets.{Paragraph, Block, Clear}
  alias ExRatatui.Text.{Line, Span}
  alias Puyopuyo.{Board, Game, Puyo}

  @cell "●"
  @ghost "○"
  @empty " "

  @doc "ゲームを開始する（ブロッキング）"
  def run do
    ExRatatui.run(fn terminal ->
      loop(terminal, Game.new(), System.monotonic_time(:millisecond))
    end)
  end

  # ------------------------------------------------------------------
  # ゲームループ
  # ------------------------------------------------------------------

  defp loop(terminal, state, last_tick) do
    draw_all(terminal, state)

    state = handle_input(state)

    if state == :quit do
      :quit
    else
      now = System.monotonic_time(:millisecond)
      {state, last_tick} = apply_gravity(state, last_tick, now)
      loop(terminal, state, last_tick)
    end
  end

  @doc """
  重力処理（純粋関数・テストから直接呼べる）。

  `now - last_tick` が重力間隔以上なら 1 ティック進めて `last_tick` を
  `now` に更新して返す。未満なら状態と last_tick はそのまま。
  ゲームオーバー中はティックしない。

  第 3 引数は「経過時間」ではなく「現在の monotonic_time 絶対時刻」を
  受け取り、更新時も絶対時刻を返す（相対/絶対の混在で重力が止まる
  バグを防ぐ）。
  """
  def apply_gravity(state, last_tick, now) do
    cond do
      Game.over?(state) ->
        {state, last_tick}

      now - last_tick >= Game.gravity_ms() ->
        {Game.tick(state), now}

      true ->
        {state, last_tick}
    end
  end

  defp handle_input(state) do
    case ExRatatui.poll_event(20) do
      %Event.Key{code: code, kind: "press"} -> apply_key(state, code)
      %Event.Key{code: code, kind: "repeat"} -> apply_key(state, code)
      %Event.Resize{} -> state
      _ -> state
    end
  end

  defp apply_key(_state, "q"), do: :quit
  defp apply_key(_state, "r"), do: Game.new()

  defp apply_key(state, key) do
    cond do
      Game.over?(state) -> state
      key in ["left", "a"] -> Game.move(state, -1)
      key in ["right", "d"] -> Game.move(state, 1)
      key in ["down", "s"] -> Game.soft_drop(state)
      key in [" ", "space"] -> Game.hard_drop(state)
      true -> state
    end
  end

  # ------------------------------------------------------------------
  # 描画
  # ------------------------------------------------------------------

  defp draw_all(terminal, state) do
    {tw, th} = safe_terminal_size()

    widgets = [
      {%Clear{}, %Rect{x: 0, y: 0, width: tw, height: th}},
      {board_paragraph(state), %Rect{x: 0, y: 0, width: 10, height: 20}},
      {next_paragraph(state), %Rect{x: 12, y: 0, width: 16, height: 12}},
      {stats_paragraph(state), %Rect{x: 12, y: 13, width: 16, height: 9}},
      {help_paragraph(), %Rect{x: 12, y: 22, width: 16, height: 12}}
    ]

    widgets =
      if Game.over?(state) do
        widgets ++
          [{game_over_paragraph(), %Rect{x: 1, y: 6, width: 8, height: 10}}]
      else
        widgets
      end

    ExRatatui.draw(terminal, widgets)
  end

  # ターミナルサイズが取得できない(0,0)場合はデフォルト値を使う
  defp safe_terminal_size do
    case ExRatatui.terminal_size() do
      {w, h} when w > 0 and h > 0 -> {w, h}
      _ -> {80, 24}
    end
  end

  # 盤面: 固定セル + ゴースト + アクティブペア
  defp board_paragraph(state) do
    lines =
      for row <- display_grid(state) do
        spans =
          Enum.map(row, fn
            {nil, _} ->
              Span.new(@empty)

            {type, :ghost} ->
              Span.new(@ghost, style: %Style{fg: Puyo.color(type), modifiers: [:dim]})

            {type, _} ->
              Span.new(@cell, style: %Style{fg: Puyo.color(type), bg: :black})
          end)

        Line.new(spans)
      end

    %Paragraph{
      text: lines,
      block: %Block{title: "ぷよぷよ", borders: [:all], border_style: %Style{fg: :blue}}
    }
  end

  @doc """
  表示グリッド: 12 行 × 2 列の `{color|nil, kind}` の 2 次元リスト。

  kind は `:locked | :ghost | :active` のいずれか。
  静止位置ではゴーストとアクティブが重複しない（アクティブのみ）。
  固定済みセルはゴースト/アクティブに上書きされない。
  """
  def display_grid(state) do
    base =
      state.board
      |> Enum.chunk_every(Board.width())
      |> Enum.map(&Enum.map(&1, fn c -> {c, :locked} end))

    if state.pair do
      active =
        state.pair
        |> Board.pair_cells()
        |> Enum.map(fn {r, c} -> {r, c, state.pair.color} end)

      active_set = active |> Enum.map(fn {r, c, _} -> {r, c} end) |> MapSet.new()

      ghost =
        if ghost = Game.ghost_pair(state) do
          ghost
          |> Board.pair_cells()
          |> Enum.map(fn {r, c} -> {r, c, ghost.color} end)
          |> Enum.reject(fn {r, c, _} -> MapSet.member?(active_set, {r, c}) end)
        else
          []
        end

      put_cells(base, ghost, :ghost)
      |> put_cells(active, :active)
    else
      base
    end
  end

  # 盤面（上書きしない）へセルリストを載せる
  defp put_cells(grid, cells, kind) do
    Enum.reduce(cells, grid, fn {row, col, type}, acc ->
      if row >= 0 and row < Board.height() and col >= 0 and col < Board.width() do
        {existing, _kind} = Enum.at(Enum.at(acc, row), col)

        # 固定済みセル（値あり）は上書き禁止。空きマス（nil）のみ上書き
        if existing == nil do
          new_row = List.replace_at(Enum.at(acc, row), col, {type, kind})
          List.replace_at(acc, row, new_row)
        else
          acc
        end
      else
        acc
      end
    end)
  end

  # 次ペア（3 つ）
  defp next_paragraph(state) do
    lines =
      state
      |> Game.next_pairs()
      |> Enum.flat_map(fn type ->
         [Line.new([span_puyo(type)]), Line.new([Span.new("")])]
       end)

    lines =
      if lines == [] do
        [Line.new([Span.new("-")])]
      else
        lines
      end

    %Paragraph{
      text: lines,
      block: %Block{title: "NEXT", borders: [:all], border_style: %Style{fg: :blue}}
    }
  end

  defp span_puyo(type),
    do: Span.new(@cell, style: %Style{fg: Puyo.color(type), bg: :black})

  # スコア / 最長連鎖 / 総消去数
  defp stats_paragraph(state) do
    text = [
      Line.new([Span.new("スコア: #{state.score}")]),
      Line.new([Span.new("最長連鎖: #{state.max_chain}")]),
      Line.new([Span.new("総消去数: #{state.total_cleared}")]),
      Line.new([Span.new("")]),
      Line.new([Span.new("重力間隔: #{Game.gravity_ms()} ms")])
    ]

    %Paragraph{
      text: text,
      block: %Block{title: "ステータス", borders: [:all], border_style: %Style{fg: :blue}}
    }
  end

  # 操作ヘルプ
  defp help_paragraph do
    text = [
      Line.new([Span.new("←/a  : 左移動")]),
      Line.new([Span.new("→/d  : 右移動")]),
      Line.new([Span.new("↓/s  : ソフトドロップ(+1/段)")]),
      Line.new([Span.new("Space: ハードドロップ(+2/段)")]),
      Line.new([Span.new("r    : リスタート")]),
      Line.new([Span.new("q    : 終了")])
    ]

    %Paragraph{
      text: text,
      block: %Block{title: "操作", borders: [:all], border_style: %Style{fg: :blue}}
    }
  end

  # ゲームオーバー表示
  defp game_over_paragraph do
    text = [
      Line.new([
        Span.new("ゲームオーバー",
          style: %Style{fg: :red, modifiers: [:bold]}
        )
      ]),
      Line.new([Span.new("")]),
      Line.new([Span.new("R : リスタート")]),
      Line.new([Span.new("Q : 終了")])
    ]

    %Paragraph{
      text: text,
      block: %Block{borders: [:all], border_style: %Style{fg: :red}}
    }
  end
end

defmodule Puyopuyo do
  @moduledoc """
  ぷよぷよ（Elixir + ex_ratatui 版）。

  実行方法:

      mix run --no-halt -e "Puyopuyo.play()"

  または:

      iex -S mix
      Puyopuyo.play()

  操作:
    ← / a    左移動
    → / d    右移動
    ↓ / s    ソフトドロップ
    Space    ハードドロップ
    q        終了
    r        リスタート
  """

  alias Puyopuyo.UI

  @doc "ゲームを開始する（ターミナルのフォアグラウンドを占有）"
  def play, do: UI.run()
end

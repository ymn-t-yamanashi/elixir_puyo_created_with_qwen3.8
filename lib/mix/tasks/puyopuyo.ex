defmodule Mix.Tasks.Puyopuyo do
  @shortdoc "ぷよぷよをプレイする"
  @moduledoc """
  ぷよぷよをプレイ開始する。

      $ mix puyopuyo

  操作:
    ← / a    : 左移動
    → / d    : 右移動
    ↓ / s    : ソフトドロップ（+1 点/段）
    Space    : ハードドロップ（+2 点/段）
    r        : リスタート
    q        : 終了
  """
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")
    Puyopuyo.play()
  end
end

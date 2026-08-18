defmodule Puyopuyo.Puyo do
  @moduledoc """
  ぷよ（色）の定義。

  4 色のぷよを持つ。各タイプは対応する表示色を返す。
  """

  @types [:red, :green, :blue, :yellow]

  # ターミナルの16/256色パレットに依存しないよう、4色とも显式な RGB を使う。
  # 名前付きアトム（:red など）は端末のカラーリング次第で区別がつかず
  # 「2色しか見えていないように見える」問題を防ぐ。
  @colors %{
    red: {:rgb, 230, 60, 60},
    green: {:rgb, 60, 200, 60},
    blue: {:rgb, 60, 90, 230},
    yellow: {:rgb, 255, 220, 0}
  }

  @doc "存在する全ぷよの色タイプ"
  def types, do: @types

  @doc """
  ぷよタイプに対応する表示色。

  iex> Puyopuyo.Puyo.color(:red)
  {:rgb, 230, 60, 60}
  """
  def color(type), do: Map.get(@colors, type, :white)

  @doc "ぷよタイプか"
  def valid?(type), do: type in @types
end

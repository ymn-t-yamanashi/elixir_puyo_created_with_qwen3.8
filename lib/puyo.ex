defmodule Puyopuyo.Puyo do
  @moduledoc """
  ぷよ（色）の定義。

  4 色のぷよを持つ。各タイプは対応する表示色を返す。
  """

  @types [:red, :green, :blue, :yellow]

  @colors %{
    red: :red,
    green: :green,
    blue: :blue,
    yellow: {:rgb, 255, 220, 0}
  }

  @doc "存在する全ぷよの色タイプ"
  def types, do: @types

  @doc """
  ぷよタイプに対応する表示色。

  iex> Puyopuyo.Puyo.color(:red)
  :red
  """
  def color(type), do: Map.get(@colors, type, :white)

  @doc "ぷよタイプか"
  def valid?(type), do: type in @types
end

defmodule Puyopuyo.Puyo do
  @moduledoc """
  ぷよ（色）の定義。

  4 色のぷよを持つ。各タイプは対応する表示色を返す。
  """

  @types [:red, :green, :blue, :yellow]

  # 表示色は xterm 256 色パレット（`{:indexed, n}`）で固定する。
  # - truecolor（`{:rgb, r, g, b}`）は非対応の端末では無視・デフォルト色に
  #   なり「全ぷよが同じ色に見える」問題が起きる
  # - 名前付きアトム（:red 等）は端末の 16 色パレット依存で区別がつかない
  # 256 色は `xterm-256color` ならほぼ全端末で共通して使える。
  # 196=鮮烈な赤 / 46=鮮烈な緑 / 33=鮮烈な青 / 226=明るい黄
  @colors %{
    red: {:indexed, 196},
    green: {:indexed, 46},
    blue: {:indexed, 33},
    yellow: {:indexed, 226}
  }

  @doc "存在する全ぷよの色タイプ"
  def types, do: @types

  @doc """
  ぷよタイプに対応する表示色。

  iex> Puyopuyo.Puyo.color(:red)
  {:indexed, 196}
  """
  def color(type), do: Map.get(@colors, type, :white)

  @doc "ぷよタイプか"
  def valid?(type), do: type in @types
end

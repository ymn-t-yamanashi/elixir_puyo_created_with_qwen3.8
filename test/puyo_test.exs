defmodule Puyopuyo.PuyoTest do
  use ExUnit.Case, async: true

  alias Puyopuyo.Puyo

  test "types/0 は 4 色を返す" do
    assert Puyo.types() == [:red, :green, :blue, :yellow]
  end

  test "color/1 は各タイプに対して表示色を返す" do
    for type <- Puyo.types() do
      color = Puyo.color(type)
      assert is_atom(color) or match?({:rgb, _, _, _}, color)
    end

    assert Puyo.color(:red) == :red
    assert Puyo.color(:yellow) == {:rgb, 255, 220, 0}
  end

  test "color/1 は未知タイプでもエラーにならずデフォルトを返す" do
    assert Puyo.color(:unknown) == :white
  end

  test "valid?/1" do
    for type <- Puyo.types(), do: assert(Puyo.valid?(type))
    refute Puyo.valid?(:unknown)
  end

  doctest Puyo
end

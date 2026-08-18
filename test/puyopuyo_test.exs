defmodule PuyopuyoTest do
  use ExUnit.Case, async: true

  test "Puyopuyo が公開APIを持つ" do
    assert function_exported?(Puyopuyo, :play, 0)
  end

  doctest Puyopuyo
end

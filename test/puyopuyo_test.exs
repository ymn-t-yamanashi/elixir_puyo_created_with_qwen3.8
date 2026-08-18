defmodule PuyopuyoTest do
  use ExUnit.Case, async: true

  test "Puyopuyo が公開APIを持つ" do
    assert function_exported?(Puyopuyo, :play, 0)
  end

  test "mix puyopuyo タスクが定義されている" do
    assert Code.ensure_loaded?(Mix.Tasks.Puyopuyo)
    assert function_exported?(Mix.Tasks.Puyopuyo, :run, 1)
  end

  doctest Puyopuyo
end

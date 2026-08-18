defmodule Puyopuyo.Application do
  @moduledoc """
  常駐プロセスを持たない TUI アプリのため、
  サブプロセス子は空のままです。

  ゲームは `Puyopuyo.play/0` を呼ぶことで起動します。
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = []
    opts = [strategy: :one_for_one, name: Puyopuyo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

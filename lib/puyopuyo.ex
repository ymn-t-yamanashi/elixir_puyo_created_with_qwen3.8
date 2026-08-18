defmodule Puyopuyo do
  @moduledoc """
  ぷよぷよ（Elixir + ex_ratatui 版）。

  実行方法:

      mix run -e "Puyopuyo.play()"

  ※ 以前は `--no-halt` が必要でしたが、`q` で終了しても VM が生きたまま
    停止し、シェルプロンプトが戻らない問題がありました。`play/0` は終了時
    に VM を確実に停止するようにしたため、`--no-halt` の有無にかかわらず
    正しく終了します。

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
  def play do
    unless interactive_tty?() do
      warn_non_tty()
      System.halt(1)
    end

    UI.run()

    # IEx セッション以外では終了時に VM を確実に停止させる。
    # これにより `mix run --no-halt` で起動した場合でも `q` で
    # シェルプロンプトが正しく戻ります。
    unless iex_session?() do
      System.stop(0)
    end
  end

  # ------------------------------------------------------------------
  # 入力環境の事前チェック
  # ------------------------------------------------------------------

  @doc """
  stdin がインタラクティブな TTY か（キー入力を扱えるか）を確認する。

  `PUYO_SKIP_TTY_CHECK=1`（`true` / `yes`）を設定するとチェックを
  スキップして `true` を返す（特殊な実行環境でのエスケープハッチ）。
  """
  def interactive_tty? do
    case System.get_env("PUYO_SKIP_TTY_CHECK") do
      v when v in ["1", "true", "yes"] -> true
      _ -> tty?()
    end
  end

  @doc "`System.cmd` の戻り値 `{stdout, status}` を TTY 判定に変換する。"
  def parse_tty?({out, 0}), do: String.trim(out) == "yes"
  def parse_tty?(_), do: true

  # BEAM プロセスの stdin が TTY かを確認する。
  # 注意: `System.cmd` の子プロセスは stdin を継承しないため
  # `test -t 0` は常に偽になる。子プロセスから /proc を経由して
  # BEAM 本体（$PPID）の fd 0 を調べ、pty（/dev/pts/* 等）かを判定する。
  # 判定不能（非 Linux / /proc なし / コマンド失敗）の場合は true（続行）。
  defp tty? do
    parse_tty?(System.cmd("sh", ["-c", tty_check_cmd()]))
  rescue
    _ -> true
  end

  defp tty_check_cmd do
    "f=$(readlink /proc/$PPID/fd/0 2>/dev/null) || f=/dev/tty; " <>
      "case \"$f\" in /dev/pts/*|/dev/tty*) echo yes ;; *) echo no ;; esac"
  end

  defp iex_session? do
    Enum.any?(Application.loaded_applications(), fn {app, _, _} -> app == :iex end)
  end

  defp warn_non_tty do
    msg = """
    ⚠ ぷよぷよは「インタラクティブなターミナル」で実行してください。
      現在の stdin は TTY ではありません（パイプ / CI / nohup 等の
      非対話コンテキスト）。この状態ではキー入力を受信できず、
      ゲームは反応しません。

      対策:
        ・普通のターミナルで:
            mix run -e "Puyopuyo.play()"
        ・チェックを無視して実行したい場合:
            PUYO_SKIP_TTY_CHECK=1 mix run -e "Puyopuyo.play()"
    """

    try do
      IO.puts(:standard_error, msg)
    rescue
      _ ->
        try do
          IO.puts(:user, msg)
        rescue
          _ -> :ok
        end
    end
  end
end

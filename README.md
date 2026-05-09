# youtube-transcribe-skill

YouTube 動画の URL を渡すだけで、ローカルで完結する文字起こしパイプラインを実行する Claude Code 用スキル。

- **mp3 化** → **文字起こし**（mlx-whisper）→ **タイムスタンプ準拠の Markdown** まで自動
- 原文が日本語以外なら **日本語訳**（タイムスタンプそのまま）を生成
- さらに **概要のまとめ** と **やさしい日本語での解説** も自動で出力
- ハルシネーションループ（末尾の繰り返し）対策をデフォルトで有効化

> 動作環境: **Apple Silicon Mac (macOS)** 専用。`mlx-whisper` が Apple Silicon の MLX フレームワークに依存しているため。

---

## ワンライナーインストール（git 不要）

```bash
curl -fsSL https://raw.githubusercontent.com/itoksk/youtube-transcribe-skill/main/install.sh | INSTALL_FROM_REMOTE=1 bash
```

これで以下が完了します:

1. 依存ツール（`yt-dlp` / `ffmpeg` / `pipx` / `mlx-whisper`）の確認・自動インストール（許可制）
2. ソースを `~/.local/share/youtube-transcribe-skill/` に配置
   - `git` があれば `git clone` で取得（後で `git pull` 更新可）
   - `git` が無ければ GitHub の **tarball を curl + tar で取得**（git アカウントすら不要）
3. `~/.claude/skills/youtube-transcribe/` にシンボリックリンクで配置

> **必要なもの**: `curl` と `tar`（macOS には標準搭載）。GitHub アカウントも `git` も不要です。

---

## ローカルクローン経由でインストール（git がある人向け）

```bash
git clone https://github.com/itoksk/youtube-transcribe-skill.git
cd youtube-transcribe-skill
bash install.sh
```

---

## 使い方

### Claude Code から

```
/youtube-transcribe https://www.youtube.com/watch?v=XXXXXXXXXXX
```

URL を貼って依頼するだけで、以下のファイルがカレントディレクトリに生成されます:

| ファイル | 内容 |
|---|---|
| `<basename>.mp3` | 抽出した音声 |
| `<basename>.srt` | mlx-whisper の生 SRT |
| `<basename>.clean.srt` | 末尾ループを切り詰めた SRT |
| `<basename>.<lang>.md` | 原文のタイムスタンプ準拠 Markdown |
| `<basename>.ja.md` | 日本語訳（原文が日本語以外のとき） |
| `<basename>.summary.md` | 概要のまとめ（章立て） |
| `<basename>.easy-ja.md` | やさしい日本語での解説 |

### コマンドラインから直接

```bash
bash ~/.claude/skills/youtube-transcribe/scripts/transcribe.sh \
  "https://www.youtube.com/watch?v=XXXXXXXXXXX"
```

オプション:

```text
-o, --out-dir <path>     出力先ディレクトリ（デフォルト: カレント）
-l, --language <code>    言語の手動指定（en / ja / auto-detect）
-m, --model <id>         Whisper モデル ID（デフォルト: whisper-large-v3-turbo）
-n, --basename <name>    出力ファイルのベース名（デフォルト: 動画タイトルから派生）
    --no-anti-loop       ループ対策フラグを外す（デバッグ用）
```

---

## 必要なツール

| ツール | 用途 | インストール |
|---|---|---|
| Homebrew | パッケージ管理 | <https://brew.sh/> |
| yt-dlp | YouTube から音声抽出 | `brew install yt-dlp` |
| ffmpeg | mp3 変換 | `brew install ffmpeg` |
| pipx | Python ツールの隔離インストール | `brew install pipx && pipx ensurepath` |
| mlx-whisper | Apple Silicon 最適化 Whisper | `pipx install mlx-whisper` |

`bash skills/youtube-transcribe/scripts/check_deps.sh --install` で自動インストールも可能です。

---

## ハルシネーション対策

mlx-whisper は動画末尾の無音・拍手・BGM 区間で同一文を延々と繰り返すループに陥ることがあります。
本スキルは2段階で対策します:

1. **入力側**: `--condition-on-previous-text False --temperature 0.2` をデフォルトで付与
2. **出力側**: `srt_to_md.py` が「同一文の3回以上連続」を検出して末尾を切り詰め

切り詰めた SRT は `<basename>.clean.srt` として残るため、検証可能です。

---

## ファイル構成

```
youtube-transcribe-skill/
├── README.md                       ← このファイル
├── INSTALL.md                      ← 詳細なインストール手順
├── LICENSE
├── install.sh                      ← ワンライナーインストーラ
└── skills/
    └── youtube-transcribe/         ← ~/.claude/skills/ にリンクされる本体
        ├── SKILL.md                ← スキルのメイン定義
        ├── scripts/
        │   ├── check_deps.sh       ← 依存チェック / 自動インストール
        │   ├── transcribe.sh       ← メインパイプライン
        │   └── srt_to_md.py        ← SRT → タイムスタンプ準拠 MD
        └── references/
            └── workflow.md         ← 内部詳細ドキュメント
```

---

## ライセンス

MIT License — 詳細は [LICENSE](./LICENSE) を参照。

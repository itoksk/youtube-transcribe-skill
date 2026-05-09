# インストールガイド

## 動作環境

- **macOS (Apple Silicon)** 専用
  - `mlx-whisper` が Apple の MLX フレームワークに依存するため
  - Intel Mac / Linux / Windows では動作しません

## ワンライナーインストール（推奨 / git 不要）

```bash
curl -fsSL https://raw.githubusercontent.com/itoksk/youtube-transcribe-skill/main/install.sh | INSTALL_FROM_REMOTE=1 bash
```

このコマンドは:

1. 依存ツール（Homebrew / yt-dlp / ffmpeg / pipx / mlx-whisper）を確認
2. 不足があれば、確認の上で自動インストール
3. ソースを `~/.local/share/youtube-transcribe-skill/` に配置
   - `git` がある: `git clone --depth=1` で取得（`cd ... && git pull` で更新可）
   - `git` が無い: GitHub の **tarball を curl + tar で展開**（GitHub アカウント不要）
4. `~/.claude/skills/youtube-transcribe/` にシンボリックリンクを作成

> **最低条件**: `curl` と `tar`（macOS 標準搭載）。`git` も GitHub アカウントも不要です。

インストール後は **新しいターミナルを開いてから** Claude Code を起動してください（`pipx ensurepath` で `~/.local/bin` が PATH に追加されるため）。

## 手動インストール

### 1. 依存ツールを順にインストール

**前提**: macOS（Apple Silicon）。`mlx-whisper` は MLX フレームワーク依存のため、Apple Silicon 専用です。

#### Step 1-1: Homebrew

未導入なら入れる（既に入っていればスキップ）:

```bash
# 確認
brew --version || true

# 未導入なら（対話式・1〜3分）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### Step 1-2: yt-dlp / ffmpeg / pipx をまとめて

```bash
brew install yt-dlp ffmpeg pipx
```

| パッケージ | 用途 |
|---|---|
| `yt-dlp` | YouTube から音声を抽出 |
| `ffmpeg` | mp3 への変換 |
| `pipx` | Python ツールを隔離した仮想環境にインストールするためのツール |

#### Step 1-3: pipx の PATH を通す

`pipx` は `~/.local/bin` にコマンドを置くため、初回だけ PATH に追加が必要:

```bash
pipx ensurepath
```

> ⚠️ **このあと必ずターミナルを再起動するか、PATH を反映してください**:
>
> ```bash
> source ~/.zshrc        # zsh の場合
> # source ~/.bashrc     # bash の場合
> ```
>
> PATH を反映していないと、次の `pipx install` が走っても `which mlx_whisper` で見つかりません。

#### Step 1-4: mlx-whisper をインストール

```bash
pipx install mlx-whisper
```

#### Step 1-5: 動作確認

```bash
which mlx_whisper
# → /Users/<you>/.local/bin/mlx_whisper が表示されれば OK
```

> 💡 **`pip install mlx-whisper` ではダメな理由**: Homebrew の Python は PEP 668 により "externally-managed-environment" になっていて、`pip install` を直接叩くとエラーになります。`pipx` は専用の仮想環境を作って隔離してくれるので、これが正解です。

### 2-A. ソースを取得（git がある場合）

```bash
git clone https://github.com/itoksk/youtube-transcribe-skill.git ~/git/youtube-transcribe-skill
cd ~/git/youtube-transcribe-skill
```

### 2-B. ソースを取得（git が無い場合 / GitHub アカウント無し）

```bash
mkdir -p ~/git && cd ~/git
curl -fsSL https://github.com/itoksk/youtube-transcribe-skill/archive/refs/heads/main.tar.gz \
  | tar -xz
mv youtube-transcribe-skill-main youtube-transcribe-skill
cd youtube-transcribe-skill
```

### 3. インストーラを実行

```bash
bash install.sh
```

これで `~/.claude/skills/youtube-transcribe/` にシンボリックリンクが作成されます。

更新方法:
- git で取得した場合: `cd <リポジトリ> && git pull`（symlink なので即時反映）
- tarball で取得した場合: 上のワンライナーを再実行

## アンインストール

```bash
rm ~/.claude/skills/youtube-transcribe
rm -rf ~/.local/share/youtube-transcribe-skill   # ワンライナー版を使った場合
```

依存ツールを巻き取りたい場合は別途:

```bash
brew uninstall yt-dlp ffmpeg
pipx uninstall mlx-whisper
```

## 動作確認

```bash
# 依存チェック
bash ~/.claude/skills/youtube-transcribe/scripts/check_deps.sh

# 試しに何か短い動画で実行
bash ~/.claude/skills/youtube-transcribe/scripts/transcribe.sh \
  "https://www.youtube.com/watch?v=dQw4w9WgXcQ" \
  --out-dir /tmp/yt-test
ls -la /tmp/yt-test/
```

## トラブルシューティング

### `mlx_whisper: command not found`

→ `pipx ensurepath` 実行後、新しいシェルを開く。または `~/.local/bin` を `PATH` に追加。

### `xcrun: error: invalid active developer path`

→ `xcode-select --install` で Command Line Tools をインストール。

### `yt-dlp` がエラーになる（古いバージョン）

→ `brew upgrade yt-dlp` で最新版に更新。

### モデルのダウンロードが遅い

→ 初回のみ数 GB ダウンロードする。Hugging Face のキャッシュ（`~/.cache/huggingface/`）に保存され、2回目以降はスキップされる。

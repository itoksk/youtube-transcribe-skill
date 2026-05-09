---
name: youtube-transcribe
description: "YouTube動画のURLを渡すと、ローカルで mp3 化＋文字起こし（mlx-whisper）し、タイムスタンプ準拠のMDを書き出す。原文が日本語以外なら日本語訳も生成。さらに概要のまとめと、やさしい日本語での解説も出力。YouTube文字起こし、mp3化、字幕抽出、動画書き起こし、SRT→MD、Whisper、英語動画の和訳、やさしい日本語要約の時に使用。"
user-invocable: true
argument-hint: "<youtube-url> [--out-dir=path] [--lang=ja]"
---

# YouTube Transcribe — 動画→mp3→文字起こし→翻訳/要約まで一気通貫

YouTube 動画の URL から、ローカルで完結する文字起こしパイプラインを実行する。
ハルシネーションループ（末尾の繰り返し）対策はデフォルトで有効。

## このスキルを使用する時

- YouTube 動画の URL を渡されて文字起こしを依頼された
- 海外の動画を翻訳付きで読みたい
- 動画の要点を素早く把握したい / やさしい日本語で配布したい
- SRT を直接渡されて、タイムスタンプ準拠の MD に整形したい

## このスキルを使用しない時

- 既に文字起こし済みのテキストへの翻訳（普通に翻訳すれば良い）
- ライブ配信のリアルタイム文字起こし（このスキルは録画済み動画専用）
- 著作権上ダウンロードが認められていない動画

---

## 出力するファイル（最大4種）

カレントディレクトリ（または `--out-dir`）に書き出す:

| ファイル | 内容 | 条件 |
|---|---|---|
| `<basename>.<lang>.md` | 原文のタイムスタンプ準拠 MD | 常に |
| `<basename>.ja.md` | 日本語訳（タイムスタンプ準拠） | 原文が日本語以外のとき |
| `<basename>.summary.md` | 概要のまとめ（章立て） | 常に |
| `<basename>.easy-ja.md` | やさしい日本語での解説 | 常に |

副生成物として `<basename>.mp3`, `<basename>.srt`, `<basename>.clean.srt` も残る（後者は末尾ループ除去後）。

`<lang>` は `en`, `ja` などの ISO コード。指定がなければ `original` をフォールバックに使う。

---

## ワークフロー

### Step 0: 依存ツールの確認

`scripts/check_deps.sh` を実行して、`yt-dlp` `ffmpeg` `pipx` `mlx_whisper` が揃っているか確認する。

```bash
bash <SKILL_DIR>/scripts/check_deps.sh
```

不足していれば、ユーザーに確認した上で `--install` で自動インストール、または該当コマンドを案内する。

### Step 1: 文字起こしパイプラインの実行

`scripts/transcribe.sh` で URL を投入。

```bash
bash <SKILL_DIR>/scripts/transcribe.sh \
  "<youtube-url>" \
  --out-dir "<出力先>" \
  --language "<en|ja|...>"   # 任意（自動検出させる場合は省略）
```

このスクリプトの出力:

- `<basename>.mp3`
- `<basename>.srt`（mlx-whisper の素の出力）
- `<basename>.clean.srt`（末尾ループを切り詰めた後）
- `<basename>.<lang>.md`（タイムスタンプ準拠 MD）

**ハルシネーションループ対策**: デフォルトで `--condition-on-previous-text False --temperature 0.2` を付与する。それでも残ることがあるため、`srt_to_md.py` 側で「同一文の3回以上連続」を検出して末尾を切り詰める。

### Step 2: 言語判定

生成された `<basename>.<lang>.md` の最初の数百文字を読み、原文が **日本語かどうか** を判定する。
（mlx-whisper は `--language` 指定があればそれを尊重するが、未指定なら自動検出するため、ここで Claude が確認する）

### Step 3: 日本語訳 MD の生成（原文が日本語以外のとき）

`<basename>.ja.md` を**タイムスタンプを保持したまま**書き出す。
**重要**: 各タイムスタンプ行の文を1対1で日本語訳する。要約しない。元の MD と行数が一致する必要がある。

書式（原文 MD と完全に同じ）:

```markdown
# <Title>

> Speaker: ...
> Source: ...
> Note: 日本語訳（mlx-whisper 出力からの整形）

---

## Transcript

**[00:00:00 → 00:00:16]** こんにちは。

**[00:00:16 → 00:00:20]** みなさんこんにちは、Boris です。

...
```

訳出のコツ:

- 一文ずつ自然な日本語に。直訳調を避ける
- 固有名詞（人名・サービス名）は原綴。"Claude Code", "GitHub", "VS Code" など
- 専門用語は和訳より原綴を優先（"agentic", "MCP", "CLI"）
- Whisper の誤認識（"QuadCode", "Cloud Code" → "Claude Code" など）に気付いたら、原文 MD 側でも合わせて修正する

### Step 4: 概要のまとめ MD（`<basename>.summary.md`）

文字起こしを通して読み、以下の構成で要約を書き出す:

```markdown
# <Title> — 概要のまとめ

> Source: <url>
> 文字起こし: <basename>.<lang>.md

## 1行サマリ

[誰が、何について、どんな主張をしているか — 1〜2行]

## 章立てサマリ

### [Chapter 1 タイトル] (00:00 - 03:25)
- 要点1
- 要点2

### [Chapter 2 タイトル] (03:25 - 07:10)
- 要点1
- 要点2

...

## 重要なフレーズ・引用

- 「原文の引用 / 訳」 — [タイムスタンプ]

## 持ち帰り（Key Takeaways）

1. ...
2. ...
3. ...
```

章の分け方は **コンテキストの切れ目**（話題転換、章番号、明示的な接続詞）で。各章は3〜10分程度を目安に。

### Step 5: やさしい日本語での解説 MD（`<basename>.easy-ja.md`）

専門知識のない読者（教職員・一般・非エンジニア）向けに書き直す。

**やさしい日本語のルール**:

- 1文を短く（30〜40文字以内が目安）
- 専門用語が出てきたら直後にカッコ書きで説明
- カタカナ語・英語は最小限に。"Claude Code"のような固有名詞は説明を添える
- 「〜のような感じです」「〜と考えてください」など、たとえ表現を活用
- 章ごとに「ここで言いたいこと」を最初と最後に置く（道しるべ）

書式:

```markdown
# <Title> — やさしい日本語での解説

> 元の動画: <url>
> 詳しい文字起こし: <basename>.<lang>.md
> 概要のまとめ: <basename>.summary.md

## この動画について

[誰が、どんな話をしているのか — 4〜5行で]

## ポイントを順番に見ていきましょう

### 1. [章タイトルをやさしく]

ここで言いたいこと: ...

[本文 — 短い文をつなげる]

### 2. ...

## まとめ

...
```

---

## ヒアリング項目

ユーザーが URL だけを渡してきた場合は、以下を確認（不明ならデフォルトで進めてよい）:

- **出力先ディレクトリ**: デフォルトはカレント
- **言語の手動指定**: 通常は自動検出。日本語なら `--language ja` を明示すると速い・正確
- **モデル**: デフォルト `whisper-large-v3-turbo`。長尺で時間優先なら `--model mlx-community/whisper-small` も可
- **要約と解説のスキップ**: 「文字起こしだけでいい」と言われたら Step 4・5 は省略

---

## トラブルシューティング

### 末尾に同じ文がループする

→ デフォルトで対策済み。`srt_to_md.py` が3回以上の連続を検出して切り詰める。
   それでも残るなら `--temperature 0.4` を試す。

### 言語誤検出される

→ `--language ja` のように明示する。

### `mlx_whisper: command not found`

→ `pipx ensurepath` 後に新しいシェルで再実行。または `~/.local/bin` を `PATH` に追加。

### Apple Silicon 以外で動かしたい

→ `mlx-whisper` は Apple Silicon 専用。x86 環境なら `openai-whisper` または `faster-whisper` に置き換える必要がある（現状このスキルは未対応）。

---

## 参考情報

- 詳細なワークフロー解説: `references/workflow.md`
- サンプル出力: `examples/`
- 関連スクリプト:
  - `scripts/check_deps.sh` — 依存チェック / 自動インストール
  - `scripts/transcribe.sh` — メインパイプライン
  - `scripts/srt_to_md.py` — SRT → タイムスタンプ準拠 MD（ループ除去内蔵）

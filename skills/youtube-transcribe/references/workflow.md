# Workflow Reference — youtube-transcribe スキルの内部詳細

## 全体像

```
[YouTube URL]
    │
    │ yt-dlp -x --audio-format mp3
    ▼
[<basename>.mp3]
    │
    │ mlx_whisper --model whisper-large-v3-turbo
    │           --output-format srt
    │           --condition-on-previous-text False
    │           --temperature 0.2
    ▼
[<basename>.srt]
    │
    │ srt_to_md.py
    │   - ループ末尾切り詰め（同一文 3 回以上連続を検出）
    │   - 任意の正規表現置換（誤認識補正）
    │   - タイムスタンプ準拠 MD 生成
    ▼
[<basename>.<lang>.md]   ← 原文 MD（タイムスタンプ準拠）
[<basename>.clean.srt]   ← ループ除去後の SRT
    │
    │ Claude による翻訳・要約・やさしい日本語化
    ▼
[<basename>.ja.md]        ← 日本語訳（タイムスタンプ準拠、原文が ja でない場合のみ）
[<basename>.summary.md]   ← 概要のまとめ（章立て）
[<basename>.easy-ja.md]   ← やさしい日本語での解説
```

## ハルシネーション対策の二段構え

mlx-whisper は動画末尾の無音・拍手・BGM 区間で同一文を繰り返すループに陥ることが知られている。
本スキルでは2段階で対策する:

1. **入力時**: `--condition-on-previous-text False --temperature 0.2`
   - 前文に引きずられにくくし、わずかに探索を散らす
2. **出力時**: `srt_to_md.py` 側で「同一文の3回以上連続」を検出し、最初に出現した位置で切り捨て

切り捨てた末尾は MD には含まれない。生 SRT は `<basename>.srt` として残し、検証可能性を担保する。

## 誤認識の補正（任意）

特定の固有名詞が一貫して誤認識される場合（例: "Claude" が "QuadCode" に化ける）は、
`srt_to_md.py` の `--replace` で正規表現置換を適用する:

```bash
python3 srt_to_md.py input.srt -o output.md \
  --replace 'QuadCode=>Claude Code' \
            'Cloud Code=>Claude Code' \
            'Quad code=>Claude Code'
```

複数指定可。先に現れたパターンから順に適用される。

## 翻訳のポリシー

- **タイムスタンプ単位で1対1**: 原文MDの各 `**[hh:mm:ss → hh:mm:ss]**` 行に対して、対応する日本語訳行を1行作る。順番・件数を保つ
- **意訳は OK、要約は NG**: 自然な日本語にするのは良いが、複数行をまとめてはいけない
- **固有名詞は原綴**: "Claude Code", "GitHub", "VS Code", "MCP", "CLI" など
- **誤認識を見つけたら原文側も直す**: 訳しているうちに気付いた誤認識は、原文 MD と訳文 MD の両方で修正する

## 概要まとめのコツ

- 章は「話題転換のタイミング」で切る。動画の章マーカーがあれば優先
- 各章 3〜10 分が目安。短すぎると章が増えすぎ、長すぎるとサマリの粒度が粗くなる
- 「重要なフレーズ・引用」は登壇者の主張がはっきり出ているフレーズを優先
- 「持ち帰り」は最大 5 つ。読者が翌日も覚えていられる粒度にする

## やさしい日本語のチェックリスト

- [ ] 1文が 40 文字を超えていない
- [ ] 知らない人が読んでも引っかからないか（固有名詞は説明を添えたか）
- [ ] 各章の冒頭に「ここで言いたいこと」がある
- [ ] 章末に「次に何の話に進むか」の道しるべがある
- [ ] カタカナ語の連続が3つを超えていない
- [ ] 例え話か図解が、抽象度の高い章に最低1つ含まれている

## モデル選択の指針

| 用途 | 推奨モデル | 速度 | 精度 |
|---|---|---|---|
| 通常（推奨） | `mlx-community/whisper-large-v3-turbo` | 速い | 高 |
| 最高精度 | `mlx-community/whisper-large-v3` | 遅い | 最高 |
| 長尺・時間優先 | `mlx-community/whisper-small` | 最速 | 中 |
| 日本語特化 | `mlx-community/whisper-large-v3-turbo` で `--language ja` | 速い | 高 |

## ファイル命名規則

```
<basename>.mp3
<basename>.srt              ← whisper の生出力
<basename>.clean.srt        ← ループ除去後
<basename>.<lang>.md        ← 原文の MD（lang は en, ja など）
<basename>.ja.md            ← 日本語訳 MD（原文が日本語のときは作らない）
<basename>.summary.md       ← 概要のまとめ
<basename>.easy-ja.md       ← やさしい日本語の解説
```

`<basename>` は yt-dlp が動画タイトルから生成する（記号などはサニタイズ済み）。
ユーザーが `--basename` を渡せば上書きできる。

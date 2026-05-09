#!/usr/bin/env python3
"""SRT を、タイムスタンプ準拠の Markdown に変換する。

特徴:
- ハルシネーションループの自動検出 & 切り捨て（同一文の3回以上連続を末尾と見なし切り捨て）
- 任意の正規表現置換による誤認識補正（--replace `pattern=>repl` を複数指定可能）
- timecode は `HH:MM:SS` 形式（ミリ秒は捨てる）

使い方:
    python srt_to_md.py input.srt -o output.md \
        --title "Title" --source "https://youtu.be/xxx" \
        --replace 'QuadCode=>Claude Code' 'Cloud Code=>Claude Code'
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Cue:
    index: int
    start: str  # HH:MM:SS,mmm
    end: str
    text: str


def parse_srt(content: str) -> list[Cue]:
    cues: list[Cue] = []
    blocks = re.split(r"\r?\n\r?\n", content.strip())
    for block in blocks:
        lines = [ln for ln in block.splitlines() if ln.strip() != ""]
        if len(lines) < 3:
            continue
        try:
            idx = int(lines[0].strip())
        except ValueError:
            continue
        timing = lines[1]
        m = re.match(
            r"^(\d{2}:\d{2}:\d{2},\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2},\d{3})\s*$",
            timing,
        )
        if not m:
            continue
        start, end = m.group(1), m.group(2)
        text = " ".join(lines[2:]).strip()
        cues.append(Cue(idx, start, end, text))
    return cues


def truncate_hallucination_loop(cues: list[Cue], min_repeat: int = 3) -> list[Cue]:
    """末尾で同一文が `min_repeat` 回以上連続したら、その始点で切り捨て。"""
    if not cues:
        return cues
    last_text = cues[-1].text.strip()
    run = 0
    cut_idx = len(cues)
    for i in range(len(cues) - 1, -1, -1):
        if cues[i].text.strip() == last_text:
            run += 1
            cut_idx = i
        else:
            break
    if run >= min_repeat:
        return cues[:cut_idx]
    return cues


def hms(timecode: str) -> str:
    """`HH:MM:SS,mmm` -> `HH:MM:SS`"""
    return timecode.split(",")[0]


def apply_replacements(text: str, replacements: list[tuple[str, str]]) -> str:
    for pat, repl in replacements:
        text = re.sub(pat, repl, text)
    return text


def to_markdown(
    cues: list[Cue],
    title: str | None,
    source: str | None,
    speaker: str | None,
    language: str | None,
    model: str | None,
    note: str | None,
) -> str:
    lines: list[str] = []
    if title:
        lines.append(f"# {title}")
        lines.append("")
    meta_lines: list[str] = []
    if speaker:
        meta_lines.append(f"> Speaker: **{speaker}**")
    if source:
        meta_lines.append(f"> Source: {source}")
    if model:
        meta_lines.append(f"> Transcribed with: `{model}`")
    if language:
        meta_lines.append(f"> Detected language: `{language}`")
    if note:
        meta_lines.append(f"> Note: {note}")
    if meta_lines:
        lines.extend(meta_lines)
        lines.append("")
        lines.append("---")
        lines.append("")
    lines.append("## Transcript")
    lines.append("")
    for cue in cues:
        if not cue.text.strip():
            continue
        lines.append(f"**[{hms(cue.start)} → {hms(cue.end)}]** {cue.text}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def parse_replace_arg(items: list[str]) -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    for it in items:
        if "=>" not in it:
            print(f"warning: ignoring malformed --replace: {it!r}", file=sys.stderr)
            continue
        pat, repl = it.split("=>", 1)
        out.append((pat, repl))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", type=Path, help="入力 SRT ファイル")
    ap.add_argument("-o", "--output", type=Path, required=True, help="出力 MD ファイル")
    ap.add_argument("--title", default=None)
    ap.add_argument("--source", default=None, help="ソース URL")
    ap.add_argument("--speaker", default=None)
    ap.add_argument("--language", default=None, help="言語コード（en, ja など）")
    ap.add_argument("--model", default=None, help="使用モデル名")
    ap.add_argument("--note", default=None)
    ap.add_argument(
        "--replace",
        nargs="*",
        default=[],
        help="正規表現置換: 'pattern=>replacement' を複数指定可",
    )
    ap.add_argument(
        "--no-trim-loop",
        action="store_true",
        help="末尾の繰り返しループを切り捨てない",
    )
    ap.add_argument(
        "--also-write-clean-srt",
        type=Path,
        default=None,
        help="ループ切り捨て＋置換適用後の SRT も書き出す",
    )
    args = ap.parse_args()

    content = args.input.read_text(encoding="utf-8")
    cues = parse_srt(content)
    if not cues:
        print("error: no cues parsed", file=sys.stderr)
        return 1

    if not args.no_trim_loop:
        cues = truncate_hallucination_loop(cues)

    replacements = parse_replace_arg(args.replace)
    for c in cues:
        c.text = apply_replacements(c.text, replacements)

    md = to_markdown(
        cues,
        title=args.title,
        source=args.source,
        speaker=args.speaker,
        language=args.language,
        model=args.model,
        note=args.note,
    )
    args.output.write_text(md, encoding="utf-8")
    print(f"wrote: {args.output} ({len(cues)} cues)")

    if args.also_write_clean_srt:
        clean_lines: list[str] = []
        for new_idx, c in enumerate(cues, start=1):
            clean_lines.append(str(new_idx))
            clean_lines.append(f"{c.start} --> {c.end}")
            clean_lines.append(c.text)
            clean_lines.append("")
        args.also_write_clean_srt.write_text("\n".join(clean_lines), encoding="utf-8")
        print(f"wrote: {args.also_write_clean_srt}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

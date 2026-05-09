#!/usr/bin/env bash
# YouTube URL → mp3 → SRT (mlx-whisper) → タイムスタンプ準拠 MD まで一気通貫。
#
# 使い方:
#   transcribe.sh <youtube-url> [-o OUT_DIR] [-l LANG] [-m MODEL] [-n BASENAME] \
#                 [--no-anti-loop]
#
# 出力（OUT_DIR/BASENAME を基準）:
#   BASENAME.mp3              ダウンロード音声
#   BASENAME.srt              生成 SRT（ループ切り詰め前）
#   BASENAME.<lang>.md        タイムスタンプ準拠 MD（ループ切り詰め後）
#   BASENAME.clean.srt        ループ切り詰め後の SRT
#
# 既定値:
#   OUT_DIR  = カレントディレクトリ
#   LANG     = （未指定なら mlx_whisper の自動検出）
#   MODEL    = mlx-community/whisper-large-v3-turbo
#   BASENAME = 動画タイトル（yt-dlp が決定）から派生

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
err()   { echo -e "${RED}[ERR]${NC} $1" >&2; }
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }

usage() {
  sed -n '2,18p' "$0"
  exit "${1:-0}"
}

URL=""
OUT_DIR="$(pwd)"
LANG=""
MODEL="mlx-community/whisper-large-v3-turbo"
BASENAME=""
ANTI_LOOP=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--out-dir)    OUT_DIR="$2"; shift 2 ;;
    -l|--language)   LANG="$2"; shift 2 ;;
    -m|--model)      MODEL="$2"; shift 2 ;;
    -n|--basename)   BASENAME="$2"; shift 2 ;;
    --no-anti-loop)  ANTI_LOOP=0; shift ;;
    -h|--help)       usage 0 ;;
    -*)
      err "Unknown option: $1"; usage 1 ;;
    *)
      if [[ -z "$URL" ]]; then URL="$1"; shift
      else err "Unexpected positional arg: $1"; usage 1; fi
      ;;
  esac
done

[[ -z "$URL" ]] && { err "URL が必要です。"; usage 1; }

# 依存チェック
if ! bash "$SCRIPT_DIR/check_deps.sh" >/dev/null 2>&1; then
  warn "依存ツールが不足しています。check_deps.sh を実行して確認してください。"
  bash "$SCRIPT_DIR/check_deps.sh" || true
  exit 1
fi

mkdir -p "$OUT_DIR"

# ベース名を決める（指定がなければ動画タイトルから）
if [[ -z "$BASENAME" ]]; then
  info "動画情報を取得中..."
  TITLE="$(yt-dlp --get-title --no-warnings "$URL" 2>/dev/null || true)"
  if [[ -z "$TITLE" ]]; then
    BASENAME="transcript_$(date +%Y%m%d_%H%M%S)"
  else
    # ファイル名に使えない文字を除去・短縮
    BASENAME="$(echo "$TITLE" | tr -cd '[:alnum:][:space:]._-' | tr -s ' ' '_' | cut -c1-80)"
  fi
fi

ok "BASENAME = $BASENAME"
ok "OUT_DIR  = $OUT_DIR"

cd "$OUT_DIR"

MP3="${BASENAME}.mp3"
SRT="${BASENAME}.srt"

# ---- 1. ダウンロード ----
if [[ -f "$MP3" ]]; then
  warn "$MP3 は既に存在するため再ダウンロードしません。"
else
  info "yt-dlp で mp3 を取得中..."
  yt-dlp -x --audio-format mp3 \
    --no-warnings \
    -o "${BASENAME}.%(ext)s" "$URL"
fi

# ---- 2. 文字起こし ----
WHISPER_ARGS=(
  "$MP3"
  --model "$MODEL"
  --output-format srt
  --output-dir "."
)

# ループ対策
if [[ $ANTI_LOOP -eq 1 ]]; then
  WHISPER_ARGS+=(--condition-on-previous-text False --temperature 0.2)
fi

# 言語指定（任意）
if [[ -n "$LANG" ]]; then
  WHISPER_ARGS+=(--language "$LANG")
fi

# whisper は <basename>.srt を生成する
info "mlx-whisper で文字起こし中..."
mlx_whisper "${WHISPER_ARGS[@]}"

# 言語自動検出ロジック: 指定がなければ MD ファイル名は .original.md にする
LANG_TAG="${LANG:-original}"
MD="${BASENAME}.${LANG_TAG}.md"
CLEAN_SRT="${BASENAME}.clean.srt"

# ---- 3. SRT → MD ----
info "SRT を Markdown に変換中..."
python3 "$SCRIPT_DIR/srt_to_md.py" \
  "$SRT" \
  -o "$MD" \
  --source "$URL" \
  --model "$MODEL" \
  --language "$LANG_TAG" \
  --also-write-clean-srt "$CLEAN_SRT"

ok "完了:"
echo "  - $OUT_DIR/$MP3"
echo "  - $OUT_DIR/$SRT          (raw)"
echo "  - $OUT_DIR/$CLEAN_SRT    (loop trimmed)"
echo "  - $OUT_DIR/$MD"

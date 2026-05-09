#!/usr/bin/env bash
# 依存ツールが揃っているか確認する。
# - 揃っていれば exit 0
# - 不足があれば、何が不足しているかを stderr に出して exit 1
# - --install を渡すと、不足分を可能な範囲で自動インストールする

set -uo pipefail

INSTALL=0
if [[ "${1:-}" == "--install" ]]; then
  INSTALL=1
fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
err()   { echo -e "${RED}[ERR]${NC} $1" >&2; }
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }

missing=()

have() { command -v "$1" >/dev/null 2>&1; }

# Homebrew (macOS で他をインストールするのに必要)
if ! have brew; then
  warn "Homebrew が見つかりません。https://brew.sh/ からインストールしてください。"
  missing+=("brew")
else
  ok "brew"
fi

# yt-dlp
if have yt-dlp; then
  ok "yt-dlp ($(yt-dlp --version 2>/dev/null))"
else
  missing+=("yt-dlp")
fi

# ffmpeg
if have ffmpeg; then
  ok "ffmpeg ($(ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}'))"
else
  missing+=("ffmpeg")
fi

# pipx (mlx-whisper のインストールに使う)
if have pipx; then
  ok "pipx ($(pipx --version 2>/dev/null))"
else
  missing+=("pipx")
fi

# mlx_whisper
if have mlx_whisper; then
  ok "mlx_whisper"
else
  missing+=("mlx_whisper")
fi

if [[ ${#missing[@]} -eq 0 ]]; then
  ok "依存ツールはすべて揃っています。"
  exit 0
fi

echo ""
warn "不足しているツール: ${missing[*]}"

if [[ $INSTALL -eq 0 ]]; then
  echo ""
  info "以下のコマンドでインストールできます:"
  echo ""
  for m in "${missing[@]}"; do
    case "$m" in
      brew)
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        ;;
      yt-dlp|ffmpeg|pipx)
        echo "  brew install $m"
        ;;
      mlx_whisper)
        echo "  pipx install mlx-whisper"
        ;;
    esac
  done
  echo ""
  info "または、このスクリプトを --install 付きで再実行してください:"
  echo "  bash $(realpath "$0") --install"
  exit 1
fi

# --install 指定時: 自動インストール
echo ""
info "依存ツールを自動インストールします..."

for m in "${missing[@]}"; do
  case "$m" in
    brew)
      err "Homebrew は対話式インストールのため自動化しません。手動で実行してください。"
      exit 1
      ;;
    yt-dlp|ffmpeg|pipx)
      info "brew install $m"
      brew install "$m"
      ;;
    mlx_whisper)
      info "pipx install mlx-whisper"
      pipx install mlx-whisper
      ;;
  esac
done

ok "インストール完了。新しいシェルで再度実行してください（PATHを反映するため）。"

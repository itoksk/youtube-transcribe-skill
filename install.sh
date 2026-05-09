#!/usr/bin/env bash
# youtube-transcribe-skill installer
#
# 動作:
#   1. 依存ツール（yt-dlp / ffmpeg / pipx / mlx-whisper）の有無を確認
#   2. 不足があれば、確認の上 brew / pipx でインストール
#   3. ~/.claude/skills/youtube-transcribe/ にスキル本体を配置（symlink）
#
# 使い方:
#   ローカル:   bash install.sh
#   ワンライナー（インストール時にこのリポジトリをクローン）:
#       curl -fsSL https://raw.githubusercontent.com/itoksk/youtube-transcribe-skill/main/install.sh \
#         | INSTALL_FROM_REMOTE=1 bash

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
err()   { echo -e "${RED}[ERR]${NC} $1" >&2; }
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }

REPO_URL="https://github.com/itoksk/youtube-transcribe-skill.git"
SKILL_NAME="youtube-transcribe"
TARGET_DIR="$HOME/.claude/skills"

# ----- リポジトリの位置を解決 -----
if [[ "${INSTALL_FROM_REMOTE:-0}" == "1" ]]; then
  TMP_DIR="$(mktemp -d)"
  info "リモートからクローン: $REPO_URL"
  git clone --depth=1 "$REPO_URL" "$TMP_DIR/youtube-transcribe-skill"
  REPO_DIR="$TMP_DIR/youtube-transcribe-skill"
  CLONE_DEST="$HOME/.local/share/youtube-transcribe-skill"
  if [[ -d "$CLONE_DEST" ]]; then
    info "既存の $CLONE_DEST を更新します"
    rm -rf "$CLONE_DEST"
  fi
  mkdir -p "$(dirname "$CLONE_DEST")"
  mv "$REPO_DIR" "$CLONE_DEST"
  REPO_DIR="$CLONE_DEST"
else
  REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

SKILL_SRC="$REPO_DIR/skills/$SKILL_NAME"
[[ -d "$SKILL_SRC" ]] || { err "スキル本体が見つかりません: $SKILL_SRC"; exit 1; }

# ----- 依存チェック / 任意でインストール -----
info "依存ツールを確認します..."
if ! bash "$SKILL_SRC/scripts/check_deps.sh"; then
  echo ""
  warn "依存ツールが不足しています。"
  read -r -p "自動でインストールしますか？ [y/N]: " ANS
  if [[ "${ANS:-N}" =~ ^[Yy] ]]; then
    bash "$SKILL_SRC/scripts/check_deps.sh" --install
  else
    info "後で手動インストールできます: bash $SKILL_SRC/scripts/check_deps.sh"
  fi
fi

# ----- スキルを ~/.claude/skills/ に配置 -----
mkdir -p "$TARGET_DIR"
DEST="$TARGET_DIR/$SKILL_NAME"

if [[ -L "$DEST" ]]; then
  rm "$DEST"; ln -s "$SKILL_SRC" "$DEST"; ok "symlink を更新: $DEST"
elif [[ -e "$DEST" ]]; then
  BACKUP="${DEST}.bak.$(date +%Y%m%d%H%M%S)"
  mv "$DEST" "$BACKUP"; warn "既存ディレクトリを退避: $BACKUP"
  ln -s "$SKILL_SRC" "$DEST"; ok "symlink を作成: $DEST"
else
  ln -s "$SKILL_SRC" "$DEST"; ok "symlink を作成: $DEST"
fi

chmod +x "$SKILL_SRC"/scripts/*.sh "$SKILL_SRC"/scripts/*.py 2>/dev/null || true

echo ""
ok "youtube-transcribe スキルをインストールしました。"
echo ""
info "使い方（Claude Code 内で）:"
echo "  /youtube-transcribe <YouTube URL>"
echo ""
info "または直接スクリプトを叩く:"
echo "  bash $SKILL_SRC/scripts/transcribe.sh <YouTube URL>"
echo ""
info "更新方法:"
echo "  cd $REPO_DIR && git pull   # symlink なので即時反映"

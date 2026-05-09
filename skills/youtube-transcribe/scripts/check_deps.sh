#!/usr/bin/env bash
# 依存ツールが揃っているか確認する。
# - 揃っていれば exit 0
# - 不足があれば、何が不足しているかを stderr に出して exit 1
# - --install を渡すと、不足分を可能な範囲で自動インストールする
#
# チェックする5点:
#   - Homebrew  (他をインストールするのに必要)
#   - yt-dlp    (YouTube から音声抽出)
#   - ffmpeg    (mp3 変換)
#   - pipx      (mlx-whisper の隔離インストールに使う)
#   - mlx_whisper (Apple Silicon 最適化 Whisper)

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

have() { command -v "$1" >/dev/null 2>&1; }

# pipx は ~/.local/bin にインストールするので、現在のシェルで PATH に
# 入っていなくても installed されているケースがある。事前に通しておく。
if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

missing=()

# Homebrew (macOS で他をインストールするのに必要)
if have brew; then
  ok "brew ($(brew --version 2>/dev/null | head -1))"
else
  missing+=("brew")
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

# ---------- インストール手順を表示するだけ ----------
if [[ $INSTALL -eq 0 ]]; then
  echo ""
  info "以下の手順でインストールできます（順番が重要）:"
  echo ""

  # Homebrew が無い場合は最優先
  if printf '%s\n' "${missing[@]}" | grep -qx brew; then
    echo '  # 1. Homebrew をインストール（対話式・約1〜3分）'
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ""
  fi

  # brew で入るもの（pipx は mlx_whisper のために必要なので必ず含める）
  brew_targets=()
  for m in yt-dlp ffmpeg pipx; do
    if printf '%s\n' "${missing[@]}" | grep -qx "$m"; then
      brew_targets+=("$m")
    fi
  done
  # mlx_whisper があるなら pipx も必須に追加
  if printf '%s\n' "${missing[@]}" | grep -qx mlx_whisper && ! have pipx; then
    if ! printf '%s\n' "${brew_targets[@]}" | grep -qx pipx; then
      brew_targets+=("pipx")
    fi
  fi

  if [[ ${#brew_targets[@]} -gt 0 ]]; then
    echo "  # 2. Homebrew で入るパッケージをまとめて"
    echo "  brew install ${brew_targets[*]}"
    echo ""
  fi

  # pipx を入れた場合は ensurepath が必要
  if printf '%s\n' "${brew_targets[@]:-}" | grep -qx pipx 2>/dev/null; then
    echo "  # 3. pipx の bin を PATH に追加（pipx 初回のみ）"
    echo "  pipx ensurepath"
    echo ""
    echo "  # 4. ⚠️ ターミナルを再起動するか、現在のシェルで PATH を反映"
    echo "  source ~/.zshrc        # zsh の場合"
    echo "  # source ~/.bashrc     # bash の場合"
    echo ""
  fi

  if printf '%s\n' "${missing[@]}" | grep -qx mlx_whisper; then
    echo "  # 5. mlx-whisper をインストール（Apple Silicon 最適化 Whisper）"
    echo "  pipx install mlx-whisper"
    echo ""
    echo "  # 6. 確認"
    echo "  which mlx_whisper      # → /Users/<you>/.local/bin/mlx_whisper が出れば OK"
    echo ""
  fi

  info "ヒント: pip ではなく pipx を使う理由 → Homebrew の Python は PEP 668 で"
  echo "          'externally-managed-environment' になっており、pip 直叩きはエラーになるため。"
  echo ""
  info "上の流れを自動で実行するには、このスクリプトを --install 付きで:"
  echo "  bash $(realpath "$0") --install"
  exit 1
fi

# ---------- 自動インストール ----------
echo ""
info "依存ツールを自動インストールします..."

# Homebrew は自動化しない（公式インストーラが対話式 sudo を求めるため）
if printf '%s\n' "${missing[@]}" | grep -qx brew; then
  err "Homebrew は対話式インストールが必要です。先に手動で:"
  echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi

# brew で入るもの
brew_pkgs=()
for m in yt-dlp ffmpeg pipx; do
  if printf '%s\n' "${missing[@]}" | grep -qx "$m"; then
    brew_pkgs+=("$m")
  fi
done
# mlx_whisper のために pipx を補完
if printf '%s\n' "${missing[@]}" | grep -qx mlx_whisper && ! have pipx; then
  if ! printf '%s\n' "${brew_pkgs[@]:-}" | grep -qx pipx 2>/dev/null; then
    brew_pkgs+=("pipx")
  fi
fi

if [[ ${#brew_pkgs[@]} -gt 0 ]]; then
  info "brew install ${brew_pkgs[*]}"
  brew install "${brew_pkgs[@]}"
fi

# pipx の PATH 反映
if printf '%s\n' "${brew_pkgs[@]:-}" | grep -qx pipx 2>/dev/null; then
  info "pipx ensurepath"
  pipx ensurepath || true
  # 現在のスクリプト実行中だけは PATH を即時反映する
  if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi

# mlx_whisper
if printf '%s\n' "${missing[@]}" | grep -qx mlx_whisper; then
  if ! have pipx; then
    err "pipx が見つかりません。先に pipx をインストールしてください。"
    exit 1
  fi
  info "pipx install mlx-whisper"
  pipx install mlx-whisper
fi

# 最終確認
echo ""
info "インストール後の確認:"
final_missing=()
for cmd in brew yt-dlp ffmpeg pipx mlx_whisper; do
  if have "$cmd"; then
    ok "$cmd"
  else
    final_missing+=("$cmd")
  fi
done

if [[ ${#final_missing[@]} -gt 0 ]]; then
  echo ""
  warn "現在のシェルでは ${final_missing[*]} がまだ見えません。"
  warn "新しいターミナルを開くか、以下を実行して PATH を反映してください:"
  echo "  source ~/.zshrc        # zsh の場合"
  echo "  # source ~/.bashrc     # bash の場合"
  echo ""
  warn "PATH 反映後、もう一度 check_deps.sh を実行してすべて [OK] になれば完了です。"
  exit 1
fi

echo ""
ok "全て使える状態になりました 🎉"

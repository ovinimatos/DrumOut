#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# DrumOut — Atualizar yt-dlp e cloudflared
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

if [ ! -d "$VENV_DIR" ]; then
  echo "❌  Virtualenv não encontrado. Execute primeiro: bash instalar.sh"
  exit 1
fi

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║         DrumOut — Atualização         ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# ── Atualizar yt-dlp ─────────────────────────
echo "📦  Atualizando yt-dlp..."
"$VENV_DIR/bin/pip" install --upgrade yt-dlp --quiet
YT_VER=$("$VENV_DIR/bin/python" -c "import yt_dlp; print(yt_dlp.version.__version__)" 2>/dev/null || echo "desconhecido")
echo "✅  yt-dlp versão: $YT_VER"

# ── Atualizar cloudflared ─────────────────────
echo "📦  Atualizando cloudflared..."
OS="$(uname -s)"
if [ "$OS" = "Darwin" ] && command -v brew &>/dev/null; then
  brew upgrade cloudflare/cloudflare/cloudflared 2>/dev/null || brew install cloudflare/cloudflare/cloudflared
elif [ -f /etc/debian_version ] || grep -qi "debian\|ubuntu" /etc/os-release 2>/dev/null; then
  ARCH="$(dpkg --print-architecture)"
  CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
  TMP_DEB="/tmp/cloudflared_update.deb"
  if command -v curl &>/dev/null; then
    curl -fsSL "$CF_URL" -o "$TMP_DEB"
  else
    wget -q "$CF_URL" -O "$TMP_DEB"
  fi
  sudo dpkg -i "$TMP_DEB"
  rm -f "$TMP_DEB"
else
  echo "⚠️   Atualize cloudflared manualmente: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
fi

CF_VER=$(cloudflared --version 2>&1 | head -1 || echo "desconhecido")
echo "✅  cloudflared: $CF_VER"

# ── Resumo ────────────────────────────────────
echo ""
echo "✅  Tudo atualizado. Rode ./start.sh para iniciar."
echo ""

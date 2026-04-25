#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# DrumOut — Script de instalação (Mac/Linux)
# ─────────────────────────────────────────────

REQUIRED_PYTHON_MAJOR=3
REQUIRED_PYTHON_MINOR=10

ok()  { echo "✅  $*"; }
err() { echo "❌  $*" >&2; }
info(){ echo "🔍  $*"; }
pkg() { echo "📦  $*"; }
done_msg() { echo "🎉  $*"; }

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║          DrumOut — Instalação         ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# ── Detectar SO ──────────────────────────────
info "Detectando sistema operacional..."
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)
    if [ -f /etc/debian_version ] || grep -qi "debian\|ubuntu" /etc/os-release 2>/dev/null; then
      PLATFORM="debian"
    else
      PLATFORM="linux_other"
    fi
    ;;
  *)
    err "Sistema operacional não suportado: $OS"
    exit 1
    ;;
esac
ok "Plataforma: $PLATFORM"

# ── Verificar Python 3.10+ ───────────────────
info "Verificando Python..."
PYTHON_BIN=""
for cmd in python3 python python3.12 python3.11 python3.10; do
  if command -v "$cmd" &>/dev/null; then
    _ver=$("$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
    _major=$(echo "$_ver" | cut -d. -f1)
    _minor=$(echo "$_ver" | cut -d. -f2)
    if [ "$_major" -eq "$REQUIRED_PYTHON_MAJOR" ] && [ "$_minor" -ge "$REQUIRED_PYTHON_MINOR" ]; then
      PYTHON_BIN="$cmd"
      ok "Python ${_ver} encontrado em: $(command -v $cmd)"
      break
    fi
  fi
done

if [ -z "$PYTHON_BIN" ]; then
  err "Python ${REQUIRED_PYTHON_MAJOR}.${REQUIRED_PYTHON_MINOR}+ não encontrado."
  echo ""
  echo "  Instale manualmente:"
  echo "    macOS  : brew install python@3.12"
  echo "    Ubuntu : sudo apt install python3.12 python3.12-venv"
  echo "    Oficial: https://www.python.org/downloads/"
  exit 1
fi

# ── Instalar ffmpeg ───────────────────────────
info "Verificando ffmpeg..."
if command -v ffmpeg &>/dev/null; then
  ok "ffmpeg já está instalado: $(ffmpeg -version 2>&1 | head -1)"
else
  pkg "Instalando ffmpeg..."
  if [ "$PLATFORM" = "macos" ]; then
    if ! command -v brew &>/dev/null; then
      err "Homebrew não encontrado. Instale em https://brew.sh e rode este script novamente."
      exit 1
    fi
    brew install ffmpeg
  elif [ "$PLATFORM" = "debian" ]; then
    sudo apt-get update -qq 2>/dev/null || true
    sudo apt-get install -y ffmpeg
  else
    err "Instale ffmpeg manualmente para seu sistema: https://ffmpeg.org/download.html"
    exit 1
  fi
  ok "ffmpeg instalado."
fi

# ── Instalar cloudflared ─────────────────────
info "Verificando cloudflared..."
if command -v cloudflared &>/dev/null; then
  ok "cloudflared já instalado: $(cloudflared --version 2>&1 | head -1)"
else
  pkg "Instalando cloudflared..."
  if [ "$PLATFORM" = "macos" ]; then
    if ! command -v brew &>/dev/null; then
      err "Homebrew não encontrado. Instale em https://brew.sh"
      exit 1
    fi
    brew install cloudflare/cloudflare/cloudflared
  elif [ "$PLATFORM" = "debian" ]; then
    ARCH="$(dpkg --print-architecture)"
    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
    TMP_DEB="/tmp/cloudflared.deb"
    info "Baixando cloudflared de $CF_URL..."
    if command -v curl &>/dev/null; then
      curl -fsSL "$CF_URL" -o "$TMP_DEB"
    elif command -v wget &>/dev/null; then
      wget -q "$CF_URL" -O "$TMP_DEB"
    else
      err "curl ou wget necessário para baixar cloudflared."
      exit 1
    fi
    sudo dpkg -i "$TMP_DEB"
    rm -f "$TMP_DEB"
  else
    err "Instale cloudflared manualmente: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
    exit 1
  fi
  ok "cloudflared instalado."
fi

# ── Criar virtualenv ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

info "Criando ambiente virtual em $VENV_DIR..."
if [ -d "$VENV_DIR" ]; then
  ok "Virtualenv já existe, reutilizando."
else
  "$PYTHON_BIN" -m venv "$VENV_DIR"
  ok "Virtualenv criado."
fi

# ── Instalar dependências ─────────────────────
pkg "Instalando dependências Python..."
"$VENV_DIR/bin/pip" install --upgrade pip --quiet
"$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
ok "Dependências instaladas."

# ── Smoke test ────────────────────────────────
info "Rodando smoke test..."
SMOKE=$("$VENV_DIR/bin/python" -c "import fastapi, yt_dlp, demucs; print('OK')" 2>&1)
if [ "$SMOKE" = "OK" ]; then
  ok "Smoke test passou: fastapi, yt_dlp, demucs importados com sucesso."
else
  err "Smoke test falhou:"
  echo "$SMOKE"
  exit 1
fi

# ── Conclusão ─────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════╗"
done_msg "Instalação concluída com sucesso!"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "  Para iniciar o DrumOut, execute:"
echo ""
echo "    bash start.sh"
echo ""

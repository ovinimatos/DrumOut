#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# DrumOut — Start (Mac/Linux)
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
PID_FILE="$SCRIPT_DIR/.uvicorn.pid"
PORT=8000

if [ ! -d "$VENV_DIR" ]; then
  echo "❌  Virtualenv não encontrado. Execute primeiro: bash instalar.sh"
  exit 1
fi

# ── Cleanup ao sair ───────────────────────────
cleanup() {
  echo ""
  echo "⏹️   Encerrando DrumOut..."
  if [ -f "$PID_FILE" ]; then
    UVICORN_PID="$(cat "$PID_FILE")"
    if kill -0 "$UVICORN_PID" 2>/dev/null; then
      kill "$UVICORN_PID" && echo "✅  uvicorn (PID $UVICORN_PID) encerrado."
    fi
    rm -f "$PID_FILE"
  fi
  exit 0
}
trap cleanup INT TERM

# ── Iniciar uvicorn em background ─────────────
echo "🚀  Iniciando uvicorn na porta $PORT..."
"$VENV_DIR/bin/python" -m uvicorn main:app --host 0.0.0.0 --port "$PORT" \
  --app-dir "$SCRIPT_DIR" &
UVICORN_PID=$!
echo "$UVICORN_PID" > "$PID_FILE"
echo "✅  uvicorn rodando (PID $UVICORN_PID)"

# ── Aguardar uvicorn subir ────────────────────
sleep 2

# ── Iniciar cloudflared tunnel ────────────────
echo ""
echo "🌐  Subindo Cloudflare Tunnel..."
echo "    A URL pública aparecerá abaixo (aguarde alguns segundos):"
echo "    ─────────────────────────────────────────────────────"
echo ""
cloudflared tunnel --url "http://localhost:$PORT"

# cleanup via trap ao Ctrl+C

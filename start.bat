@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: ─────────────────────────────────────────────
:: DrumOut — Start (Windows)
:: ─────────────────────────────────────────────

set "SCRIPT_DIR=%~dp0"
set "VENV_DIR=%SCRIPT_DIR%venv"
set "PORT=8000"

if not exist "%VENV_DIR%\" (
    echo ❌  Virtualenv não encontrado. Execute primeiro: instalar.bat
    pause
    exit /b 1
)

echo 🚀  Iniciando uvicorn na porta %PORT%...
start "DrumOut-uvicorn" /B "%VENV_DIR%\Scripts\python.exe" -m uvicorn main:app --host 0.0.0.0 --port %PORT% --app-dir "%SCRIPT_DIR%"

echo ✅  uvicorn iniciado em background.
echo.

:: Aguardar uvicorn subir
timeout /t 3 /nobreak >nul

echo 🌐  Subindo Cloudflare Tunnel...
echo     A URL publica aparecera abaixo (aguarde alguns segundos):
echo     ─────────────────────────────────────────────────────
echo.

cloudflared tunnel --url http://localhost:%PORT%

echo.
echo ⏹️   Tunnel encerrado. Encerrando uvicorn...
taskkill /FI "WINDOWTITLE eq DrumOut-uvicorn" /F >nul 2>&1
echo ✅  Encerrado.
pause

@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

echo.
echo ╔═══════════════════════════════════════╗
echo ║      DrumOut — Instalação (Windows)   ║
echo ╚═══════════════════════════════════════╝
echo.

:: ── Verificar Python ─────────────────────────
echo 🔍  Verificando Python...
set "PYTHON_BIN="

for %%P in (python python3) do (
    where %%P >nul 2>&1
    if !errorlevel! == 0 (
        for /f "tokens=*" %%V in ('%%P -c "import sys; v=sys.version_info; print(f'{v.major}.{v.minor}')" 2^>^&1') do (
            set "PY_VER=%%V"
        )
        for /f "tokens=1,2 delims=." %%A in ("!PY_VER!") do (
            set "PY_MAJOR=%%A"
            set "PY_MINOR=%%B"
        )
        if !PY_MAJOR! == 3 (
            if !PY_MINOR! GEQ 10 (
                set "PYTHON_BIN=%%P"
                echo ✅  Python !PY_VER! encontrado.
                goto :python_found
            )
        )
    )
)

echo ❌  Python 3.10+ não encontrado.
echo.
echo     Instale em: https://www.python.org/downloads/
echo     Marque "Add Python to PATH" durante a instalação.
echo.
pause
exit /b 1

:python_found

:: ── Verificar ffmpeg ─────────────────────────
echo 🔍  Verificando ffmpeg...
where ffmpeg >nul 2>&1
if %errorlevel% == 0 (
    echo ✅  ffmpeg já instalado.
) else (
    echo 📦  Tentando instalar ffmpeg via winget...
    winget install --id Gyan.FFmpeg -e --silent >nul 2>&1
    if !errorlevel! == 0 (
        echo ✅  ffmpeg instalado via winget.
    ) else (
        echo ❌  Não foi possível instalar ffmpeg automaticamente.
        echo.
        echo     Instale manualmente:
        echo       1. Acesse https://ffmpeg.org/download.html
        echo       2. Baixe a build para Windows
        echo       3. Extraia e adicione a pasta bin ao PATH do sistema
        echo.
        pause
        exit /b 1
    )
)

:: ── Verificar/instalar cloudflared ───────────
echo 🔍  Verificando cloudflared...
where cloudflared >nul 2>&1
if %errorlevel% == 0 (
    echo ✅  cloudflared já instalado.
) else (
    echo 📦  Tentando instalar cloudflared via winget...
    winget install --id Cloudflare.cloudflared -e --silent >nul 2>&1
    if !errorlevel! == 0 (
        echo ✅  cloudflared instalado via winget.
    ) else (
        echo ❌  Não foi possível instalar cloudflared automaticamente.
        echo.
        echo     Instale manualmente:
        echo       1. Acesse https://github.com/cloudflare/cloudflared/releases/latest
        echo       2. Baixe cloudflared-windows-amd64.exe
        echo       3. Renomeie para cloudflared.exe e mova para C:\Windows\System32\
        echo.
        pause
        exit /b 1
    )
)

:: ── Criar virtualenv ──────────────────────────
set "SCRIPT_DIR=%~dp0"
set "VENV_DIR=%SCRIPT_DIR%venv"

echo 🔍  Criando ambiente virtual...
if exist "%VENV_DIR%\" (
    echo ✅  Virtualenv já existe, reutilizando.
) else (
    %PYTHON_BIN% -m venv "%VENV_DIR%"
    if !errorlevel! NEQ 0 (
        echo ❌  Falha ao criar virtualenv.
        pause
        exit /b 1
    )
    echo ✅  Virtualenv criado.
)

:: ── Instalar dependências ─────────────────────
echo 📦  Instalando dependências Python...
"%VENV_DIR%\Scripts\pip.exe" install --upgrade pip --quiet
"%VENV_DIR%\Scripts\pip.exe" install -r "%SCRIPT_DIR%requirements.txt"
if %errorlevel% NEQ 0 (
    echo ❌  Falha ao instalar dependências.
    pause
    exit /b 1
)
echo ✅  Dependências instaladas.

:: ── Smoke test ────────────────────────────────
echo 🔍  Rodando smoke test...
"%VENV_DIR%\Scripts\python.exe" -c "import fastapi, yt_dlp, demucs; print('OK')" >nul 2>&1
if %errorlevel% == 0 (
    echo ✅  Smoke test passou: fastapi, yt_dlp, demucs OK.
) else (
    echo ❌  Smoke test falhou. Verifique os erros acima.
    pause
    exit /b 1
)

:: ── Conclusão ─────────────────────────────────
echo.
echo ╔═══════════════════════════════════════╗
echo 🎉  Instalação concluída com sucesso!
echo ╚═══════════════════════════════════════╝
echo.
echo   Para iniciar o DrumOut, execute:
echo.
echo     start.bat
echo.
pause

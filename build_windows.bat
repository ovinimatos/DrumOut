@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1
title DrumOut — Build

echo.
echo ╔══════════════════════════════════════════════════╗
echo ║      DrumOut — Build Script (Windows)            ║
echo ╚══════════════════════════════════════════════════╝
echo.

:: ── Configurações ────────────────────────────────────────────────────────────
set "BUILD_DIR=%~dp0"
:: Remove trailing backslash
if "%BUILD_DIR:~-1%"=="\" set "BUILD_DIR=%BUILD_DIR:~0,-1%"

set "VENV_DIR=%BUILD_DIR%\venv_build"
set "DIST_DIR=%BUILD_DIR%\dist\DrumOut"
set "ASSETS_DIR=%BUILD_DIR%\assets"

:: CPU_ONLY=1  →  torch CPU (~300 MB), bundle final ~800 MB-1.2 GB
:: CPU_ONLY=0  →  torch CUDA (~3 GB),  bundle final ~4-5 GB
set "CPU_ONLY=1"

:: ── [1/7] Verificar Python ────────────────────────────────────────────────────
echo [1/7] Verificando Python 3.10+...
python --version >nul 2>&1
if %errorlevel% NEQ 0 (
    echo.
    echo ERRO: Python nao encontrado no PATH.
    echo Instale em: https://www.python.org/downloads/
    echo Marque "Add Python to PATH" durante a instalacao.
    pause & exit /b 1
)
for /f "tokens=2" %%V in ('python --version 2^>^&1') do set "PY_VER=%%V"
echo OK: Python %PY_VER% encontrado.

:: ── [2/7] Criar venv limpo de build ──────────────────────────────────────────
echo.
echo [2/7] Criando venv de build limpo...
if exist "%VENV_DIR%" (
    echo     Removendo venv antigo...
    rmdir /s /q "%VENV_DIR%"
)
python -m venv "%VENV_DIR%"
if %errorlevel% NEQ 0 ( echo ERRO ao criar venv & pause & exit /b 1 )

set "PIP=%VENV_DIR%\Scripts\pip.exe"
set "PYTHON=%VENV_DIR%\Scripts\python.exe"

"%PIP%" install --upgrade pip --quiet
echo OK: venv criado em %VENV_DIR%

:: ── [3/7] Instalar dependências Python ───────────────────────────────────────
echo.
echo [3/7] Instalando dependencias Python...

if "%CPU_ONLY%"=="1" (
    echo     Modo CPU-only: instalando torch sem CUDA ~300 MB...
    "%PIP%" install torch torchaudio --index-url https://download.pytorch.org/whl/cpu --quiet
) else (
    echo     Modo GPU-CUDA 12.1: instalando torch com CUDA ~3 GB...
    "%PIP%" install torch torchaudio --index-url https://download.pytorch.org/whl/cu121 --quiet
)

"%PIP%" install ^
    fastapi==0.115.0 ^
    "uvicorn==0.30.6" ^
    "yt-dlp>=2024.11.4" ^
    "demucs>=4.0.1" ^
    python-multipart==0.0.12 ^
    "pywebview>=5.0" ^
    "pyinstaller>=6.10.0" ^
    --quiet

if %errorlevel% NEQ 0 ( echo ERRO ao instalar dependencias & pause & exit /b 1 )
echo OK: Dependencias instaladas.

:: ── [4/7] Verificar assets obrigatórios ──────────────────────────────────────
echo.
echo [4/7] Verificando assets necessarios...
if not exist "%ASSETS_DIR%" mkdir "%ASSETS_DIR%"

:: ffmpeg.exe — obrigatório
if not exist "%ASSETS_DIR%\ffmpeg.exe" (
    echo.
    echo ERRO: assets\ffmpeg.exe nao encontrado!
    echo.
    echo  1. Acesse: https://www.gyan.dev/ffmpeg/builds/
    echo  2. Baixe:  ffmpeg-release-essentials.zip
    echo  3. Extraia e copie  bin\ffmpeg.exe  para:
    echo     %ASSETS_DIR%\ffmpeg.exe
    echo.
    pause & exit /b 1
)
echo OK: ffmpeg.exe encontrado.

:: WebView2 Bootstrapper — baixa automaticamente se ausente
if not exist "%ASSETS_DIR%\MicrosoftEdgeWebview2Setup.exe" (
    echo     Baixando WebView2 Bootstrapper ~1.4 MB...
    curl -L --silent -o "%ASSETS_DIR%\MicrosoftEdgeWebview2Setup.exe" ^
        "https://go.microsoft.com/fwlink/p/?LinkId=2124703"
    if !errorlevel! EQU 0 (
        echo OK: WebView2 Bootstrapper baixado.
    ) else (
        echo AVISO: Falha ao baixar WebView2. Continuando sem ele.
    )
)

:: VC++ Redistributable — baixa automaticamente se ausente
if not exist "%ASSETS_DIR%\vc_redist.x64.exe" (
    echo     Baixando VC++ Redistributable ~25 MB...
    curl -L --silent -o "%ASSETS_DIR%\vc_redist.x64.exe" ^
        "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    if !errorlevel! EQU 0 (
        echo OK: VC++ Redistributable baixado.
    ) else (
        echo AVISO: Falha ao baixar VC++ Redist. Continuando sem ele.
    )
)

:: ── [5/7] Rodar PyInstaller ───────────────────────────────────────────────────
echo.
echo [5/7] Rodando PyInstaller (pode levar 5-20 minutos)...

:: Limpa builds anteriores
if exist "%BUILD_DIR%\build" rmdir /s /q "%BUILD_DIR%\build"
if exist "%BUILD_DIR%\dist"  rmdir /s /q "%BUILD_DIR%\dist"

cd /d "%BUILD_DIR%"
"%VENV_DIR%\Scripts\pyinstaller.exe" drumout.spec --noconfirm --clean

if %errorlevel% NEQ 0 (
    echo.
    echo ERRO no PyInstaller! Leia os logs acima para identificar o problema.
    echo Dicas:
    echo   - Verifique se todos os pacotes estao instalados no venv_build
    echo   - Se um import falhar, adicione-o em hiddenimports no drumout.spec
    pause & exit /b 1
)
echo OK: PyInstaller concluido. Bundle em: %DIST_DIR%

:: ── [6/7] Copiar assets para dist/ ───────────────────────────────────────────
echo.
echo [6/7] Copiando assets para dist\DrumOut\...

:: ffmpeg ao lado do DrumOut.exe (encontrado via PATH em app.py)
copy /Y "%ASSETS_DIR%\ffmpeg.exe" "%DIST_DIR%\" >nul
echo OK: ffmpeg.exe copiado.

:: ── [7/7] Compilar instalador Inno Setup ─────────────────────────────────────
echo.
echo [7/7] Compilando instalador Inno Setup...

if not exist "%BUILD_DIR%\installer_output" mkdir "%BUILD_DIR%\installer_output"

:: Procura ISCC.exe nos locais padrão
set "ISCC="
for %%P in (
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles(x86)%\Inno Setup 5\ISCC.exe"
) do (
    if exist "%%~P" set "ISCC=%%~P"
)

if not defined ISCC (
    echo.
    echo AVISO: Inno Setup nao encontrado.
    echo Instale em: https://jrsoftware.org/isdl.php
    echo.
    echo Para gerar o instalador:
    echo   1. Instale o Inno Setup 6
    echo   2. Abra setup.iss no IDE do Inno Setup
    echo   3. Clique em Build ^> Compile
    echo.
    echo Bundle gerado com sucesso em:
    echo   %DIST_DIR%
    goto :summary
)

"%ISCC%" "%BUILD_DIR%\setup.iss"
if %errorlevel% NEQ 0 (
    echo ERRO na compilacao do Inno Setup.
    pause & exit /b 1
)
echo OK: Instalador gerado em installer_output\

:summary
echo.
echo ╔══════════════════════════════════════════════════╗
echo ║         Build concluido com sucesso!             ║
echo ╚══════════════════════════════════════════════════╝
echo.
echo  Bundle (para teste direto):
echo    %DIST_DIR%\DrumOut.exe
echo.
if defined ISCC (
    echo  Instalador:
    echo    %BUILD_DIR%\installer_output\DrumOut_Setup_v1.0.0.exe
    echo.
)
echo  Proximos passos:
echo    1. Teste o bundle: execute DrumOut.exe na pasta dist\DrumOut\
echo    2. Instale em VM limpa com o instalador .exe gerado
echo    3. Verifique atalhos no Desktop e Menu Iniciar
echo.
pause

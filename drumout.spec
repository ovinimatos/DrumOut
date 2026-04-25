# -*- mode: python ; coding: utf-8 -*-
#
# PyInstaller spec for DrumOut — Windows Desktop App
# Run with:  pyinstaller drumout.spec --clean
#
# Produces: dist/DrumOut/ (one-dir bundle)
#

from PyInstaller.utils.hooks import collect_all, collect_data_files, collect_submodules

# ── Accumulate datas / binaries / hidden imports ──────────────────────────────

datas = [
    ('frontend', 'frontend'),  # HTML/CSS/JS frontend
    ('main.py',  '.'),         # FastAPI app module
]
binaries    = []
hiddenimports = []

# Demucs and audio ML deps
for pkg in ('demucs', 'torchaudio', 'julius', 'einops', 'openunmix', 'dora'):
    try:
        _d, _b, _h = collect_all(pkg)
        datas        += _d
        binaries     += _b
        hiddenimports += _h
    except Exception:
        pass  # skip if package not present in build env

# torch — data files only (very large; avoids double-bundling .py)
try:
    datas += collect_data_files('torch', include_py_files=False)
    hiddenimports += collect_submodules('torch')
except Exception:
    pass

# yt-dlp
try:
    _d, _b, _h = collect_all('yt_dlp')
    datas += _d; binaries += _b; hiddenimports += _h
except Exception:
    pass

# FastAPI / Uvicorn / Pydantic / Starlette
hiddenimports += [
    'fastapi',
    'fastapi.middleware.cors',
    'fastapi.staticfiles',
    'fastapi.responses',
    'pydantic',
    'starlette',
    'starlette.middleware',
    'starlette.routing',
    'starlette.staticfiles',
    'starlette.responses',
    'uvicorn',
    'uvicorn.logging',
    'uvicorn.loops',
    'uvicorn.loops.auto',
    'uvicorn.loops.asyncio',
    'uvicorn.protocols',
    'uvicorn.protocols.http',
    'uvicorn.protocols.http.auto',
    'uvicorn.protocols.http.h11_impl',
    'uvicorn.protocols.websockets',
    'uvicorn.protocols.websockets.auto',
    'uvicorn.lifespan',
    'uvicorn.lifespan.on',
    'uvicorn.lifespan.off',
    'h11',
    'anyio',
    'anyio._backends._asyncio',
    'python_multipart',
    'multipart',
]

# pywebview — Windows uses WinForms / WebView2
hiddenimports += [
    'webview',
    'webview.platforms.winforms',
    'webview.platforms.cef',
    'clr',
    'System',
    'System.Windows.Forms',
]

# ── Analysis ─────────────────────────────────────────────────────────────────

a = Analysis(
    ['app.py'],
    pathex=['.'],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Remove GPU / CUDA to keep CPU-only build lean
        'nvidia',
        'triton',
        'bitsandbytes',
        # Dev tools
        'pytest',
        'IPython',
        'matplotlib',
        'PIL',
        'cv2',
        'sklearn',
    ],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='DrumOut',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,          # compress with UPX if available
    console=False,     # no black terminal window
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    # icon='assets/icon.ico',  # uncomment when icon file exists
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='DrumOut',
)

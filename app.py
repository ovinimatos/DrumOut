"""
DrumOut — Desktop entry point (Windows)
Starts the FastAPI/Uvicorn server in a background thread and opens
a native window via pywebview (Edge WebView2).
"""

import os
import sys
import time
import threading
from pathlib import Path

# When frozen by PyInstaller, add the exe directory to PATH so that
# ffmpeg.exe (placed next to DrumOut.exe) is found by yt-dlp.
if getattr(sys, 'frozen', False):
    exe_dir = str(Path(sys.executable).parent)
    os.environ["PATH"] = exe_dir + os.pathsep + os.environ.get("PATH", "")

import webview
import uvicorn

PORT = 17832


def start_server() -> None:
    config = uvicorn.Config(
        "main:app",
        host="127.0.0.1",
        port=PORT,
        log_level="warning",
        access_log=False,
    )
    server = uvicorn.Server(config)
    server.run()


def wait_for_server(timeout: int = 15) -> bool:
    import urllib.request
    url = f"http://127.0.0.1:{PORT}/"
    for _ in range(timeout * 2):
        try:
            urllib.request.urlopen(url, timeout=1)
            return True
        except Exception:
            time.sleep(0.5)
    return False


if __name__ == "__main__":
    t = threading.Thread(target=start_server, daemon=True)
    t.start()

    if not wait_for_server():
        try:
            import tkinter
            import tkinter.messagebox as mb
            root = tkinter.Tk()
            root.withdraw()
            mb.showerror("DrumOut", "Erro ao iniciar o servidor interno.\nTente reiniciar o aplicativo.")
            root.destroy()
        except Exception:
            pass
        sys.exit(1)

    webview.create_window(
        title="DrumOut",
        url=f"http://127.0.0.1:{PORT}/",
        width=780,
        height=660,
        resizable=True,
        min_size=(560, 500),
    )
    webview.start()

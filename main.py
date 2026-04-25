import os
import sys
import shutil
import subprocess
import uuid
import logging
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Dirs
# ---------------------------------------------------------------------------

if getattr(sys, 'frozen', False):
    # Rodando como bundle PyInstaller
    BASE_DIR = Path(sys._MEIPASS)
    TMP_DIR = Path.home() / "AppData" / "Local" / "DrumOut" / "tmp"
else:
    BASE_DIR = Path(__file__).parent
    TMP_DIR = BASE_DIR / "tmp"
FRONTEND_DIR = BASE_DIR / "frontend"

TMP_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(title="DrumOut")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=str(FRONTEND_DIR)), name="static")


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class ProcessRequest(BaseModel):
    url: str


class ProcessResponse(BaseModel):
    title: str
    download_url: str


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/", response_class=HTMLResponse)
async def index():
    index_file = FRONTEND_DIR / "index.html"
    if not index_file.exists():
        raise HTTPException(status_code=404, detail="frontend/index.html não encontrado")
    return HTMLResponse(content=index_file.read_text(encoding="utf-8"))


@app.post("/process", response_model=ProcessResponse)
async def process(req: ProcessRequest):
    job_id = str(uuid.uuid4())
    job_dir = TMP_DIR / job_id

    log.info(f"[{job_id}] Iniciando processamento — URL: {req.url}")

    try:
        job_dir.mkdir(parents=True, exist_ok=True)

        # ------------------------------------------------------------------
        # 1. Baixar áudio com yt-dlp
        # ------------------------------------------------------------------
        log.info(f"[{job_id}] Baixando áudio com yt-dlp...")

        audio_template = str(job_dir / "audio.%(ext)s")
        # sys.executable garante que o yt_dlp do bundle PyInstaller é usado
        # em vez de buscar "yt-dlp" no PATH do sistema
        yt_cmd = [
            sys.executable, "-m", "yt_dlp",
            "--no-playlist",
            "--extract-audio",
            "--audio-format", "mp3",
            "--audio-quality", "192K",
            "--output", audio_template,
            "--print", "title",
            req.url,
        ]

        yt_result = subprocess.run(
            yt_cmd,
            capture_output=True,
            text=True,
            timeout=600,
        )

        if yt_result.returncode != 0:
            err = yt_result.stderr.strip() or yt_result.stdout.strip()
            log.error(f"[{job_id}] yt-dlp falhou: {err}")
            raise HTTPException(
                status_code=500,
                detail=f"Erro ao baixar o vídeo: {err[:300]}",
            )

        title = yt_result.stdout.strip().splitlines()[-1] if yt_result.stdout.strip() else "audio"
        log.info(f"[{job_id}] Título: {title}")

        # Localiza o MP3 baixado
        mp3_files = list(job_dir.glob("*.mp3"))
        if not mp3_files:
            raise HTTPException(
                status_code=500,
                detail="yt-dlp não gerou arquivo MP3.",
            )
        audio_path = mp3_files[0]
        log.info(f"[{job_id}] Áudio baixado: {audio_path.name}")

        # ------------------------------------------------------------------
        # 2. Rodar Demucs
        # ------------------------------------------------------------------
        log.info(f"[{job_id}] Rodando Demucs (htdemucs --two-stems=drums)...")

        demucs_cmd = [
            sys.executable, "-m", "demucs",
            "--two-stems", "drums",
            "--mp3",
            "--mp3-bitrate", "192",
            "-n", "htdemucs",
            "-o", str(job_dir),
            str(audio_path),
        ]

        demucs_result = subprocess.run(
            demucs_cmd,
            capture_output=True,
            text=True,
            timeout=600,
        )

        if demucs_result.returncode != 0:
            err = demucs_result.stderr.strip() or demucs_result.stdout.strip()
            log.error(f"[{job_id}] Demucs falhou: {err}")
            raise HTTPException(
                status_code=500,
                detail=f"Erro no Demucs: {err[:300]}",
            )

        # ------------------------------------------------------------------
        # 3. Localizar no_drums.mp3 gerado pelo Demucs
        # ------------------------------------------------------------------
        log.info(f"[{job_id}] Localizando no_drums.mp3...")

        no_drums_candidates = list(job_dir.rglob("no_drums.mp3"))
        if not no_drums_candidates:
            # Fallback: qualquer arquivo que contenha "no_drums"
            no_drums_candidates = list(job_dir.rglob("*no_drums*"))

        if not no_drums_candidates:
            files_found = [str(p) for p in job_dir.rglob("*")]
            log.error(f"[{job_id}] Arquivos encontrados: {files_found}")
            raise HTTPException(
                status_code=500,
                detail="Arquivo no_drums não encontrado após Demucs.",
            )

        no_drums_path = no_drums_candidates[0]
        log.info(f"[{job_id}] no_drums encontrado: {no_drums_path}")

        # ------------------------------------------------------------------
        # 4. Copiar para destino final e limpar temporários
        # ------------------------------------------------------------------
        output_filename = f"{job_id}_sem_bateria.mp3"
        output_path = TMP_DIR / output_filename

        shutil.copy2(no_drums_path, output_path)
        log.info(f"[{job_id}] Arquivo final: {output_path}")

        shutil.rmtree(job_dir, ignore_errors=True)
        log.info(f"[{job_id}] Pasta temporária removida.")

        return ProcessResponse(
            title=title,
            download_url=f"/download/{output_filename}",
        )

    except HTTPException:
        shutil.rmtree(job_dir, ignore_errors=True)
        raise
    except subprocess.TimeoutExpired:
        shutil.rmtree(job_dir, ignore_errors=True)
        log.error(f"[{job_id}] Timeout após 600s")
        raise HTTPException(
            status_code=500,
            detail="Timeout: o processamento demorou mais de 10 minutos.",
        )
    except Exception as exc:
        shutil.rmtree(job_dir, ignore_errors=True)
        log.exception(f"[{job_id}] Erro inesperado: {exc}")
        raise HTTPException(
            status_code=500,
            detail=f"Erro inesperado: {str(exc)}",
        )


@app.get("/download/{filename}")
async def download(filename: str):
    # Sanitize: apenas nome de arquivo, sem path traversal
    safe_name = Path(filename).name
    file_path = TMP_DIR / safe_name

    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Arquivo não encontrado.")

    return FileResponse(
        path=str(file_path),
        media_type="audio/mpeg",
        filename=safe_name,
    )


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)

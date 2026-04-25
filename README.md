# DrumOut 🥁

> Remove a bateria de qualquer música do YouTube em segundos.

---

## 1. O que é o DrumOut

DrumOut é um web app que recebe uma URL do YouTube, baixa o áudio com **yt-dlp**, separa a bateria usando **Demucs** (Meta AI, modelo `htdemucs`) e entrega um MP3 sem bateria para download.

O acesso pelo celular é feito via **Cloudflare Tunnel** — que expõe o servidor local com uma URL pública HTTPS usando seu IP residencial, evitando bloqueios do YouTube.

---

## 2. Pré-requisitos

| Requisito   | Versão mínima | Notas |
|-------------|---------------|-------|
| Python      | 3.10+         | `python3 --version` |
| ffmpeg      | qualquer      | instalado pelo `instalar.sh` |
| cloudflared | qualquer      | instalado pelo `instalar.sh` |
| RAM         | 4 GB          | Demucs é pesado |
| Espaço      | 2 GB livres   | modelos + arquivos temporários |

---

## 3. Instalação

```bash
# Clone ou extraia o projeto, depois:
bash instalar.sh
```

O script faz tudo automaticamente:
- Verifica Python 3.10+
- Instala ffmpeg e cloudflared
- Cria virtualenv em `./venv`
- Instala todas as dependências Python
- Roda smoke test para confirmar que está OK

**Windows:** execute `instalar.bat` no Prompt de Comando ou PowerShell.

---

## 4. Como usar

```bash
bash start.sh
```

1. O uvicorn sobe na porta 8000
2. O cloudflared gera uma URL pública (ex: `https://abc123.trycloudflare.com`)
3. Abra essa URL no celular
4. Cole o link do YouTube
5. Clique em **Processar** e aguarde
6. Baixe o MP3 sem bateria

**Windows:** execute `start.bat`.

---

## 5. Arquitetura

```
Celular / Navegador
      │
      │  HTTPS
      ▼
┌─────────────────────────┐
│  Cloudflare Tunnel      │  trycloudflare.com (sem login)
│  (cloudflared)          │
└──────────┬──────────────┘
           │  HTTP local
           ▼
┌─────────────────────────┐
│  FastAPI / uvicorn      │  localhost:8000
│  (main.py)              │
│                         │
│  ┌─────────┐            │
│  │ yt-dlp  │ ←── URL YouTube
│  └────┬────┘            │
│       │ MP3             │
│  ┌────▼────┐            │
│  │ Demucs  │ htdemucs --two-stems=drums
│  └────┬────┘            │
│       │ no_drums.mp3    │
└───────┼─────────────────┘
        │
        ▼  download
     Celular
```

---

## 6. Tempo estimado de processamento

| Hardware             | Música de 4 min | Observação |
|----------------------|-----------------|------------|
| CPU comum (i5/Ryzen 5) | 8–15 min      | Demucs usa todos os núcleos |
| Apple Silicon (M1+)   | 2–4 min        | MPS backend |
| GPU NVIDIA (RTX 3060+) | 30–90 s       | CUDA automático |

---

## 7. Solução de problemas

**YouTube bloqueou o download**
- O IP do Cloudflare Tunnel pode ser bloqueado eventualmente.
- Solução: o túnel usa seu IP residencial. Se falhar, tente novamente em alguns minutos.
- Alternativa: use cookies com `yt-dlp --cookies-from-browser chrome`.

**Demucs travou ou demorou demais**
- Verifique se tem RAM suficiente (mínimo 4 GB livres).
- Com GPU NVIDIA: instale `torch` com suporte CUDA (`pip install torch --index-url https://download.pytorch.org/whl/cu121`).
- O timeout é de 10 minutos. Para músicas longas, edite `timeout=600` em `main.py`.

**Porta 8000 em uso**
```bash
lsof -i :8000       # Encontra o processo
kill -9 <PID>       # Encerra
```
Ou altere `PORT=8000` no `start.sh`.

**cloudflared não encontra o servidor**
- Aguarde 3–5 segundos após iniciar — o uvicorn precisa de tempo para subir.
- Verifique se o uvicorn está rodando: `curl http://localhost:8000`.

---

## 8. Aviso de uso pessoal

Este projeto é para uso **estritamente pessoal**.  
Não distribua conteúdo protegido por direitos autorais.  
Respeite os Termos de Serviço do YouTube.

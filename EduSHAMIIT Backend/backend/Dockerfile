FROM python:3.11-slim

WORKDIR /app

# Only curl is needed for the HEALTHCHECK.
# gcc and libpq-dev are NOT needed — no C-extension DB drivers are used.
# ffmpeg is NOT needed — Flutter records WAV which SpeechRecognition handles natively.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

# Use gunicorn with uvicorn workers for process management + graceful shutdown
# --max-requests: restart workers after handling N requests to prevent memory leaks
# --max-requests-jitter: adds randomness to prevent thundering herd restarts
CMD ["gunicorn", "app.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "4", \
     "--max-requests", "1000", \
     "--max-requests-jitter", "50", \
     "--timeout", "120", \
     "--keep-alive", "5", \
     "--access-logfile", "-"]
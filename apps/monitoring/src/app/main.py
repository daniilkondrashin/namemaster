from __future__ import annotations

import asyncio
import json
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import AsyncIterator

from fastapi import FastAPI, Response, status
from fastapi.responses import HTMLResponse, JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.requests import Request

from app.kubernetes_client import KubernetesClientFactory, KubernetesReader
from app.metrics import MonitorCollector, prometheus_response

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parent
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))


def _poll_interval() -> float:
    raw = os.getenv("METRICS_POLL_INTERVAL", "5")
    try:
        return max(float(raw), 1.0)
    except ValueError:
        logger.warning("Invalid METRICS_POLL_INTERVAL=%r, using 5 seconds", raw)
        return 5.0


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    factory = KubernetesClientFactory()
    clients = factory.load()
    collector = MonitorCollector(KubernetesReader(clients), poll_interval=_poll_interval())
    app.state.kubernetes_factory = factory
    app.state.collector = collector
    await collector.start()
    try:
        yield
    finally:
        await collector.stop()


app = FastAPI(title="Kubernetes Monitor", lifespan=lifespan)
app.mount("/static", StaticFiles(directory=str(BASE_DIR / "static")), name="static")


@app.get("/", response_class=HTMLResponse)
async def index(request: Request) -> HTMLResponse:
    return templates.TemplateResponse("index.html", {"request": request})


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/readyz")
async def readyz(request: Request) -> JSONResponse:
    ready, message = await asyncio.to_thread(request.app.state.kubernetes_factory.ready)
    code = status.HTTP_200_OK if ready else status.HTTP_503_SERVICE_UNAVAILABLE
    return JSONResponse({"status": "ok" if ready else "error", "message": message}, status_code=code)


@app.get("/api/snapshot")
async def api_snapshot(request: Request) -> dict[str, object]:
    _, snapshot = await request.app.state.collector.snapshot()
    return snapshot.to_dict()


@app.get("/api/events")
async def api_events(request: Request) -> StreamingResponse:
    async def stream() -> AsyncIterator[str]:
        version = -1
        while True:
            if await request.is_disconnected():
                break
            version, snapshot = await request.app.state.collector.wait_for_update(version)
            payload = json.dumps(snapshot.to_dict(), separators=(",", ":"))
            yield f"event: snapshot\ndata: {payload}\n\n"

    return StreamingResponse(stream(), media_type="text/event-stream")


@app.get("/metrics")
async def metrics() -> Response:
    body, content_type = prometheus_response()
    return Response(content=body, media_type=content_type)

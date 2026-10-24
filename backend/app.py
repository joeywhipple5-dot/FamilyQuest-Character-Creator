
import os
import asyncio
from pathlib import Path

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="Family Quest Character Creator API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

API_KEY = os.getenv("TRIPO_API_KEY", "")
BASE_URL = "https://api.tripo3d.ai/v2/openapi"
CACHE = Path("generated_models")
CACHE.mkdir(exist_ok=True)

class GenerateRequest(BaseModel):
    prompt: str = Field(min_length=5, max_length=2000)
    name: str = Field(default="New Character", max_length=100)

@app.get("/health")
def health():
    return {"status": "online", "service": "Family Quest Character Creator"}

@app.post("/generate")
async def generate(request: GenerateRequest):
    if not API_KEY:
        raise HTTPException(
            status_code=503,
            detail="AI service is not configured. Set TRIPO_API_KEY on the server."
        )

    headers = {"Authorization": f"Bearer {API_KEY}"}
    payload = {
        "type": "text_to_model",
        "prompt": request.prompt,
        "model_version": "v2.5-20250123",
        "texture": True,
        "pbr": True,
    }

    async with httpx.AsyncClient(timeout=60) as client:
        response = await client.post(
            f"{BASE_URL}/task",
            headers=headers,
            json=payload,
        )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail="The AI provider rejected the generation request."
        )

    result = response.json()
    task_id = result.get("data", {}).get("task_id")
    if not task_id:
        raise HTTPException(status_code=502, detail="No task ID returned.")

    return {"task_id": task_id, "name": request.name}

@app.get("/status/{task_id}")
async def status(task_id: str):
    if not API_KEY:
        raise HTTPException(status_code=503, detail="AI service not configured.")

    headers = {"Authorization": f"Bearer {API_KEY}"}
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.get(
            f"{BASE_URL}/task/{task_id}",
            headers=headers,
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail="Could not check task status.")

    data = response.json().get("data", {})
    output = data.get("output", {})
    return {
        "task_id": task_id,
        "status": data.get("status", "unknown"),
        "progress": data.get("progress", 0),
        "model_url": output.get("pbr_model") or output.get("model"),
    }

@app.get("/download/{task_id}")
async def download(task_id: str):
    if not API_KEY:
        raise HTTPException(status_code=503, detail="AI service not configured.")

    headers = {"Authorization": f"Bearer {API_KEY}"}
    async with httpx.AsyncClient(timeout=60) as client:
        response = await client.get(
            f"{BASE_URL}/task/{task_id}",
            headers=headers,
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail="Could not retrieve model.")

    data = response.json().get("data", {})
    if data.get("status") != "success":
        raise HTTPException(status_code=409, detail="Model is not ready yet.")

    output = data.get("output", {})
    model_url = output.get("pbr_model") or output.get("model")
    if not model_url:
        raise HTTPException(status_code=502, detail="No model file available.")

    return {"task_id": task_id, "model_url": model_url}

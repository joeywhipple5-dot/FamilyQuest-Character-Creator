
import os
import re

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field

app = FastAPI(title="Family Quest Character Creator API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

API_KEY = os.getenv("TRIPO_API_KEY", "")
BASE_URL = "https://openapi.tripo3d.com/v3"


class GenerateRequest(BaseModel):
    prompt: str = Field(min_length=5, max_length=1024)
    name: str = Field(default="New Character", max_length=100)


def get_headers():
    return {"Authorization": f"Bearer {API_KEY}"}


@app.get("/health")
def health():
    return {
        "status": "online",
        "service": "Family Quest Character Creator",
    }


@app.post("/generate")
async def generate(request: GenerateRequest):
    if not API_KEY:
        raise HTTPException(
            status_code=503,
            detail="AI service is not configured.",
        )

    payload = {
        "prompt": request.prompt,
        "model": "v3.1-20260211",
        "texture": True,
        "pbr": True,
    }

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.post(
                f"{BASE_URL}/generation/text-to-model",
                headers=get_headers(),
                json=payload,
            )
            response.raise_for_status()
            result = response.json()
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail="The AI provider rejected the request.",
        ) from exc
    except (httpx.RequestError, ValueError) as exc:
        raise HTTPException(
            status_code=502,
            detail="Could not contact the AI provider.",
        ) from exc

    task_id = result.get("data", {}).get("task_id")
    if not task_id:
        raise HTTPException(
            status_code=502,
            detail="The AI provider did not return a task ID.",
        )

    return {"task_id": task_id, "name": request.name}


@app.get("/status/{task_id}")
async def status(task_id: str):
    if not API_KEY:
        raise HTTPException(
            status_code=503,
            detail="AI service is not configured.",
        )

    if not re.fullmatch(r"[A-Za-z0-9_-]+", task_id):
        raise HTTPException(status_code=400, detail="Invalid task ID.")

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.get(
                f"{BASE_URL}/tasks/{task_id}",
                headers=get_headers(),
            )
            response.raise_for_status()
            result = response.json()
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail="Could not check the AI task.",
        ) from exc
    except (httpx.RequestError, ValueError) as exc:
        raise HTTPException(
            status_code=502,
            detail="Could not contact the AI provider.",
        ) from exc

    data = result.get("data", {})
    output = data.get("output", {})

    return {
        "task_id": task_id,
        "status": data.get("status", "unknown"),
        "progress": data.get("progress", 0),
        "model_url": output.get("model_url"),
    }


@app.get("/download/{task_id}")
async def download(task_id: str):
    if not API_KEY:
        raise HTTPException(
            status_code=503,
            detail="AI service is not configured.",
        )

    if not re.fullmatch(r"[A-Za-z0-9_-]+", task_id):
        raise HTTPException(status_code=400, detail="Invalid task ID.")

    try:
        async with httpx.AsyncClient(
            timeout=120,
            follow_redirects=True,
        ) as client:
            task_response = await client.get(
                f"{BASE_URL}/tasks/{task_id}",
                headers=get_headers(),
            )
            task_response.raise_for_status()
            task_data = task_response.json().get("data", {})

            if task_data.get("status") != "success":
                raise HTTPException(
                    status_code=409,
                    detail="The model is not ready yet.",
                )

            model_url = task_data.get("output", {}).get("model_url")
            if not model_url:
                raise HTTPException(
                    status_code=502,
                    detail="No model download URL was returned.",
                )

            model_response = await client.get(model_url)
            model_response.raise_for_status()
            model_bytes = model_response.content

    except HTTPException:
        raise
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail="Could not retrieve the generated model.",
        ) from exc
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=502,
            detail="A network error occurred during download.",
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=502,
            detail="The AI provider returned an invalid response.",
        ) from exc

    return Response(
        content=model_bytes,
        media_type="model/gltf-binary",
        headers={
            "Content-Disposition": 'attachment; filename="family_quest_model.glb"'
        },
    )

import os
import time
from collections import defaultdict, deque
from typing import Literal

from fastapi import FastAPI, HTTPException, Request
from openai import OpenAI
from pydantic import BaseModel, Field


app = FastAPI(title="RefineKeyboard API")
request_log: dict[str, deque[float]] = defaultdict(deque)


class RefineRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    mode: Literal["Polish", "Warm", "Professional", "Shorter"] = "Polish"
    language: str = Field(default="Auto", max_length=80)


class RefineResponse(BaseModel):
    text: str


SYSTEM_PROMPT = """You rewrite user-written messages.
Return only the rewritten message, with no quotes, labels, or explanation.
Preserve the user's meaning and do not invent facts."""


MODE_INSTRUCTIONS = {
    "Polish": "Fix grammar, spelling, flow, and clarity while keeping the original tone.",
    "Warm": "Make the message warmer, more natural, and kind without becoming overly formal.",
    "Professional": "Make the message clear, polished, and professional without sounding stiff.",
    "Shorter": "Make the message more concise while preserving the meaning.",
}


def client_ip(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for", "")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def check_rate_limit(request: Request) -> None:
    max_requests = int(os.getenv("REFINE_MAX_REQUESTS_PER_MINUTE", "30"))
    now = time.time()
    window_start = now - 60
    ip = client_ip(request)
    timestamps = request_log[ip]

    while timestamps and timestamps[0] < window_start:
        timestamps.popleft()

    if len(timestamps) >= max_requests:
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

    timestamps.append(now)


@app.get("/")
def root() -> dict[str, str]:
    return {"name": "RefineKeyboard API", "status": "ok"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/refine", response_model=RefineResponse)
def refine(payload: RefineRequest, request: Request) -> RefineResponse:
    check_rate_limit(request)

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="OPENAI_API_KEY is not configured")

    client = OpenAI(api_key=api_key)
    language_instruction = (
        "Keep the output in the same language as the input."
        if payload.language == "Auto"
        else f"Write the output in {payload.language}."
    )
    prompt = (
        f"Rewrite task: {MODE_INSTRUCTIONS[payload.mode]}\n"
        f"Language: {language_instruction}\n\n"
        f"Message:\n{payload.text}"
    )

    response = client.responses.create(
        model=os.getenv("OPENAI_MODEL", "gpt-5.4-nano"),
        instructions=SYSTEM_PROMPT,
        input=prompt,
        max_output_tokens=500,
    )

    refined = response.output_text.strip()
    if not refined:
        raise HTTPException(status_code=502, detail="Model returned an empty rewrite")

    return RefineResponse(text=refined)

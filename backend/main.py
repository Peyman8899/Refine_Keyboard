import os
import time
from collections import defaultdict, deque
from typing import Literal

from fastapi import FastAPI, HTTPException, Request
from openai import OpenAI
from pydantic import BaseModel, Field


app = FastAPI(title="RefineKeyboard API")
request_log: dict[str, deque[float]] = defaultdict(deque)

_openai_client: OpenAI | None = None


def get_openai_client() -> OpenAI:
    global _openai_client
    if _openai_client is None:
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise HTTPException(status_code=500, detail="OPENAI_API_KEY is not configured")
        _openai_client = OpenAI(api_key=api_key)
    return _openai_client


class RefineRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    mode: Literal["Polish", "Warm", "Professional", "Shorter", "Translate",
                  "Grammar", "Flirty", "Street", "Funny", "Custom"] = "Polish"
    language: str = Field(default="Auto", max_length=80)
    custom_instruction: str = Field(default="", max_length=500)


class RefineResponse(BaseModel):
    text: str


SYSTEM_PROMPT = """You are a precise text rewriter that produces natural, human-sounding output.
Output ONLY the rewritten message, starting directly with its first word.
Never use bullet points, dashes, numbered lists, or any markdown formatting.
Never add preamble, labels, headers, quotes, or explanations.
Never reference or echo the rewriting instruction.
Write in flowing natural prose that sounds like a real person wrote it — not like AI output."""


MODE_INSTRUCTIONS = {
    "Polish": "Fix grammar, spelling, flow, and clarity while keeping the original tone.",
    "Warm": "Make the message warmer, more natural, and kind without becoming overly formal.",
    "Professional": "Make the message clear, polished, and professional without sounding stiff.",
    "Shorter": "Make the message more concise while preserving the meaning.",
    "Translate": "Translate the message into the target language. Preserve meaning, tone, and formatting exactly. Output only the translation.",
    "Grammar": "Correct only grammar errors, spelling mistakes, and punctuation (commas, periods, apostrophes, capitalization). Preserve the exact wording and tone — only fix what is grammatically wrong.",
    "Flirty": "Rewrite in a playful, flirtatious, and charming tone. Keep it fun, light, and engaging — perfect for dating and romantic conversations.",
    "Street": "Rewrite in a casual cool street style using modern urban slang. Sound confident and authentic, like someone who is naturally trendy. Keep it real.",
    "Funny": "Rewrite to be witty and funny while keeping the core message. Add humor, a clever twist, or playful energy without being offensive.",
    "Custom": "",  # handled separately using custom_instruction
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


def check_app_secret(request: Request) -> None:
    expected = os.getenv("REFINE_APP_SECRET", "")
    if not expected:
        return  # Secret not configured — skip check (dev/local mode)
    received = request.headers.get("X-App-Secret", "")
    if received != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.get("/")
def root() -> dict[str, str]:
    return {"name": "RefineKeyboard API", "status": "ok"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/refine", response_model=RefineResponse)
def refine(payload: RefineRequest, request: Request) -> RefineResponse:
    check_app_secret(request)
    check_rate_limit(request)

    language_instruction = (
        "Same language as the input."
        if payload.language == "Auto"
        else f"{payload.language}."
    )

    if payload.mode == "Custom":
        if not payload.custom_instruction.strip():
            raise HTTPException(status_code=400, detail="custom_instruction is required for Custom mode")
        prompt = (
            f"Style/tone: {payload.custom_instruction.strip()}\n"
            f"Output language: {language_instruction}\n\n"
            f"Text to rewrite:\n{payload.text}"
        )
    else:
        task_instruction = MODE_INSTRUCTIONS[payload.mode]
        prompt = (
            f"Task: {task_instruction}\n"
            f"Output language: {language_instruction}\n\n"
            f"Text to rewrite:\n{payload.text}"
        )

    response = get_openai_client().responses.create(
        model=os.getenv("OPENAI_MODEL", "gpt-5.4-nano"),
        instructions=SYSTEM_PROMPT,
        input=prompt,
        max_output_tokens=500,
    )

    refined = response.output_text.strip()
    if not refined:
        raise HTTPException(status_code=502, detail="Model returned an empty rewrite")

    return RefineResponse(text=refined)

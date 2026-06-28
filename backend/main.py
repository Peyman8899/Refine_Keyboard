import os
import time
from collections import defaultdict, deque
from typing import Literal

from fastapi import FastAPI, HTTPException, Request, Response
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
                  "Grammar", "Flirty", "Vibe", "Funny", "Custom"] = "Polish"
    language: str = Field(default="Auto", max_length=80)
    custom_instruction: str = Field(default="", max_length=500)


class RefineResponse(BaseModel):
    text: str


SYSTEM_PROMPT = """You are a precise text rewriter that produces natural, human-sounding output.
Output ONLY the rewritten text, starting directly with its first word.
Never use bullet points, dashes, numbered lists, or any markdown formatting.
Never add preamble, labels, headers, quotes, or explanations.
Never reference or echo the rewriting instruction.
Write in flowing natural prose — the kind a real person would actually send."""


MODE_INSTRUCTIONS = {
    "Polish": (
        "Polish this message for clarity, flow, and correctness. Fix grammar, spelling, and awkward phrasing. "
        "Keep the original tone, intent, and approximate length — don't add new ideas or change the meaning."
    ),
    "Warm": (
        "Rewrite with genuine warmth and empathy. Make it feel heartfelt and human — like you truly care. "
        "Conversational and kind, but never sappy, excessive, or over-the-top."
    ),
    "Professional": (
        "Rewrite in a clear, confident, and professional tone. Use precise language and eliminate filler words, "
        "hedging, and informal expressions. Sound authoritative yet approachable — polished, not stiff."
    ),
    "Shorter": (
        "Cut this message down to its bare essentials. Keep only what truly needs to be said. "
        "Remove every filler word, redundant phrase, and unnecessary detail. Every word must earn its place."
    ),
    "Translate": (
        "Translate the message into the target language. Preserve meaning, tone, register, and style exactly. "
        "Output only the translation — nothing else."
    ),
    "Grammar": (
        "Correct only grammar errors, spelling mistakes, and punctuation issues (commas, periods, apostrophes, "
        "capitalization). Do not change the wording, tone, or style in any other way — only fix what is wrong."
    ),
    "Flirty": (
        "Rewrite in a playful, flirtatious, and charming tone. Add a touch of wit and confidence. "
        "Keep it light, fun, and engaging — never desperate, needy, or over-the-top."
    ),
    "Vibe": (
        "Rewrite in a relaxed, effortless, and modern tone — like texting your coolest friend. "
        "Sound natural, confident, and real. Use casual contemporary language without trying too hard. "
        "Low-key, smooth, and authentic."
    ),
    "Funny": (
        "Make it funny. Add wit, a clever twist, or playful humor while keeping the core message intact. "
        "Be genuinely funny — not forced or try-hard. Light-hearted and fun, never mean-spirited."
    ),
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
        instruction = payload.custom_instruction.strip() or "Rewrite in a creative and natural style."
        prompt = (
            f"Style/tone: {instruction}\n"
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


class SpeakRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4096)
    voice: str = Field(default="nova")


@app.post("/speak")
def speak_text(payload: SpeakRequest, request: Request) -> Response:
    check_app_secret(request)
    check_rate_limit(request)
    audio = get_openai_client().audio.speech.create(
        model="tts-1",
        voice=payload.voice,
        input=payload.text,
    )
    return Response(content=audio.content, media_type="audio/mpeg")

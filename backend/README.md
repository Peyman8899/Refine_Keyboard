# RefineKeyboard API

FastAPI service used by the iOS keyboard extension. It keeps the OpenAI API key on the server, not inside the app.

## Local Run

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
OPENAI_API_KEY=your_key uvicorn main:app --host 0.0.0.0 --port 8000
```

Health check:

```bash
curl http://localhost:8000/health
```

Rewrite endpoint:

```bash
curl -X POST http://localhost:8000/refine \
  -H "Content-Type: application/json" \
  -d '{"text":"hello how are you","mode":"Professional"}'
```

## Deploy on Render

1. Push this project to GitHub.
2. In Render, create a new Blueprint from the repo.
3. Render will read `render.yaml`.
4. Set `OPENAI_API_KEY` as a secret environment variable.
5. Add a custom domain such as `api.refinekeyboard.app`.
6. Point your DNS to the value Render gives you.

The default model is `gpt-5.4-nano` to keep rewrite costs low.

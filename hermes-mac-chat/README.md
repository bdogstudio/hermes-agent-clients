# Hermes Mac Chat

Electron desktop client for a self-hosted Hermes Agent API Server.

Hermes Mac Chat gives macOS users a native-feeling window for realtime Hermes Agent chat, persistent Responses conversations, Runs event streams, tool progress events, and Cron Job management.

## Features

- Realtime streaming chat using `/v1/chat/completions`
- Responses API mode with `previous_response_id`
- Runs mode with structured event streaming
- Cron Job list, create, pause, resume, run now, and delete
- Health and model checks
- System prompt and `max_tokens` controls
- Response record read/delete tools
- No committed API keys

## Run Locally

```bash
npm install
npm start
```

Optional environment configuration:

```bash
HERMES_BASE_URL="http://YOUR_HERMES_HOST:8642/v1" \
HERMES_API_KEY="your-api-server-key" \
npm start
```

## Configure In App

- Base URL: `http://YOUR_HERMES_HOST:8642/v1`
- API Key: your Hermes `API_SERVER_KEY`
- Model: `hermes-agent`
- System prompt: optional
- Output limit: optional `max_tokens`

## Modes

- **Realtime Chat**: streams assistant output through `/v1/chat/completions`.
- **Responses**: uses `/v1/responses` and chains `previous_response_id`.
- **Runs**: submits async tasks through `/v1/runs` and reads `/v1/runs/{run_id}/events`.
- **Cron Jobs**: manages scheduled tasks through `/api/jobs`.

## Security

This app does not ship with a real API key or server address. Use HTTPS for public deployments when possible.

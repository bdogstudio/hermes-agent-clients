# Hermes Agent Clients

Cross-platform desktop and mobile clients for a self-hosted [Hermes Agent](https://github.com/NousResearch/hermes-agent) API Server.

This repository contains a macOS Electron app and a SwiftUI iOS app for chatting with Hermes Agent, streaming tool progress, managing persistent Responses conversations, running asynchronous tasks, and controlling Cron Jobs from a friendly local UI.

## Why This Exists

Hermes Agent can expose an OpenAI-compatible API server, but most users still need a polished client to use it like a real assistant app. This project turns a self-hosted Hermes Agent into something closer to Telegram, Feishu, or ChatGPT Desktop:

- realtime streaming chat
- persistent conversation chains
- structured run/event monitoring
- cron job management
- local settings and API key handling
- macOS and iPhone clients from one repo

## Apps

| App | Stack | Status | Path |
| --- | --- | --- | --- |
| Hermes Mac Chat | Electron, HTML, CSS, JavaScript | Usable desktop client | `hermes-mac-chat/` |
| Hermes iOS | SwiftUI, URLSession, Keychain | Xcode project scaffold | `hermes-ios/` |

## Features

- **OpenAI-compatible chat** via `POST /v1/chat/completions`
- **SSE streaming** with `delta.content`
- **Hermes tool progress events** such as `hermes.tool.progress`
- **Responses API** via `POST /v1/responses`
- **Persistent conversation chaining** through `previous_response_id`
- **Saved response lookup and deletion**
- **Runs API** via `POST /v1/runs` and `/v1/runs/{run_id}/events`
- **Cron Job management** through `/api/jobs`
- **Health and model checks** through `/health`, `/health/detailed`, and `/v1/models`
- **No committed secrets**: API keys are configured locally

## Supported Hermes API Endpoints

The clients are built around these Hermes Agent API Server endpoints:

```text
GET    /health
GET    /health/detailed
GET    /v1/health
GET    /v1/models
POST   /v1/chat/completions
POST   /v1/responses
GET    /v1/responses/{response_id}
DELETE /v1/responses/{response_id}
POST   /v1/runs
GET    /v1/runs/{run_id}/events
GET    /api/jobs
POST   /api/jobs
GET    /api/jobs/{job_id}
PATCH  /api/jobs/{job_id}
DELETE /api/jobs/{job_id}
POST   /api/jobs/{job_id}/pause
POST   /api/jobs/{job_id}/resume
POST   /api/jobs/{job_id}/run
```

Authentication uses:

```http
Authorization: Bearer <API_SERVER_KEY>
```

## Quick Start: macOS

```bash
cd hermes-mac-chat
npm install
npm start
```

Then configure:

```text
Base URL: http://YOUR_HERMES_HOST:8642/v1
API Key:  your API_SERVER_KEY
Model:    hermes-agent
```

## Quick Start: iOS

1. Install Xcode and iOS platform components.
2. Open:

   ```text
   hermes-ios/HermesIOS.xcodeproj
   ```

3. Select your Apple Developer Team in Signing & Capabilities.
4. Run on an iPhone or iOS Simulator.
5. Open Settings in the app and enter your Hermes API Server details.

## Security Notes

- API keys are not committed.
- The checked-in defaults use placeholders:

  ```text
  http://YOUR_HERMES_HOST:8642/v1
  ```

- The iOS app stores API keys in Keychain.
- The macOS Electron app stores user-entered settings locally in Electron app storage.
- Prefer HTTPS for any public deployment. HTTP is supported for local and private network testing.

## Keywords

Hermes Agent client, Hermes Agent desktop app, Hermes Agent iOS app, self-hosted AI assistant, OpenAI compatible API client, SSE streaming chat UI, agent tool progress UI, Responses API client, Cron Job AI assistant, local AI agent client.

## Roadmap

- packaged macOS `.app` and `.dmg`
- screenshots and demo video
- signed and notarized macOS builds
- TestFlight build for iOS
- APNs or polling notifications for Cron Job results
- multi-profile server switching

## License

MIT

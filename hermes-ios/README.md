# Hermes iOS

SwiftUI iPhone/iPad client for a self-hosted Hermes Agent API Server.

The iOS app mirrors the desktop client: realtime chat, Responses conversation chaining, Runs event streaming, Cron Job management, and local settings. API keys are stored in iOS Keychain.

## Features

- `/v1/chat/completions` SSE streaming
- `/v1/responses` with `previous_response_id`
- `/v1/runs` and `/v1/runs/{run_id}/events`
- `/api/jobs` Cron Job management
- Settings for Base URL, API key, model, system prompt, and `max_tokens`
- API key stored with Keychain

## Run On iPhone

1. Install Xcode and iOS platform components.
2. Open:

   ```text
   HermesIOS.xcodeproj
   ```

3. Choose your Apple Developer Team in Signing & Capabilities.
4. Connect your iPhone and enable Developer Mode.
5. Run from Xcode.

## Default Server

The checked-in default is a placeholder:

```text
http://YOUR_HERMES_HOST:8642/v1
```

The generated `Info.plist` allows HTTP for development. For long-term or public use, put Hermes Agent behind HTTPS.

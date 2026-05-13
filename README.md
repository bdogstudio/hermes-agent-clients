# Hermes Agent Clients

Desktop and iOS clients for a self-hosted Hermes Agent API Server.

## Apps

- `hermes-mac-chat`: Electron macOS desktop client.
- `hermes-ios`: SwiftUI iPhone/iPad client.

## Security

No API keys are committed. Configure your own Hermes API Server URL and `API_SERVER_KEY` inside each app.

The checked-in defaults use placeholders:

```text
http://YOUR_HERMES_HOST:8642/v1
```

## macOS

```bash
cd hermes-mac-chat
npm install
npm start
```

## iOS

Open:

```text
hermes-ios/HermesIOS.xcodeproj
```

Then choose your signing team in Xcode and run on an iPhone or simulator.

# RefineKeyboard

A native iOS custom keyboard that reads the current draft text, sends it to an AI rewrite endpoint, and replaces the draft with a polished version.

## What is included

- `RefineKeyboardApp`: SwiftUI host app for onboarding and endpoint settings.
- `RefineKeyboardExtension`: iOS custom keyboard extension with a `Refine` action.
- `backend`: minimal FastAPI rewrite service that keeps the OpenAI API key off the phone.

## Current status

This is an MVP scaffold. It is designed for local iPhone testing through Xcode first. Before App Store submission, add authentication, App Store subscriptions, analytics, stronger privacy controls, and production backend hosting.

## Setup

1. Install Xcode from the Mac App Store.
2. Open `RefineKeyboard.xcodeproj`.
3. Sign in to Xcode with your Apple ID:
   - Xcode -> Settings -> Accounts
   - Add your Apple ID
   - Let Xcode create/download an Apple Development certificate
4. Select your Apple Developer Team for both targets:
   - `RefineKeyboard`
   - `RefineKeyboardExtension`
5. Change bundle IDs if needed:
   - `com.peyman.RefineKeyboard`
   - `com.peyman.RefineKeyboard.Keyboard`
6. Update the app group in both entitlement files if your Apple account requires a different value.
7. Connect your iPhone and select it as the run destination.
8. Run the app on your iPhone.
9. On iPhone, enable the keyboard:
   - Settings -> General -> Keyboard -> Keyboards -> Add New Keyboard
   - Select `RefineKeyboard`
   - Enable `Allow Full Access`

The keyboard needs Full Access to call the backend over the network.

## Local build check

The project currently passes a no-signing device build:

```bash
xcodebuild \
  -project RefineKeyboard.xcodeproj \
  -scheme RefineKeyboard \
  -configuration Debug \
  -sdk iphoneos \
  -destination generic/platform=iOS \
  -derivedDataPath ./DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

A signed device build requires an Apple Development certificate and a development team selected in Xcode for both targets.

If device discovery fails right after installing Xcode, open Xcode once from `/Applications`, let it finish setup, then restart the Mac if `xcrun devicectl list devices` still times out.

## Backend

From `backend`:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
OPENAI_API_KEY=your_key uvicorn main:app --host 0.0.0.0 --port 8000
```

For iPhone testing, the backend must be reachable from the phone. Use a LAN IP address, a tunnel, or deploy it to a host such as Render/Fly/Railway.

Set the endpoint in the iOS app as:

```text
https://your-domain.example/refine
```

or for local LAN testing:

```text
http://192.168.1.50:8000/refine
```

For the current deployed backend, keep the iOS app pointed at:

```text
https://refinekeyboard-api.onrender.com/refine
```

For production branding, add the custom domain `api.refinekeyboard.app` in Render, update DNS, then switch the iOS app endpoint to `https://api.refinekeyboard.app/refine`.

## Privacy note

The keyboard only sends text when the user taps `Refine`. Do not send text on every keystroke. Before selling this, add a clear privacy policy explaining what is sent, where it is processed, and whether logs are retained.

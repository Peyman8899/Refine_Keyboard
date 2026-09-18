# RefineKeyboard — App Review Notes

Use the text below both in the Resolution Center reply and in **App Review Information → Notes** for the resubmitted version.

## Copy-and-paste response

Hello App Review,

Thank you for reviewing RefineKeyboard. The app is complete and ready for review. We have tested the app and keyboard extension on supported physical iPhone and iPad devices running the latest available iOS/iPadOS version. A physical-device screen recording showing the complete typical user flow is attached to our Resolution Center reply.

### 1. Physical-device screen recording

The attached recording begins with launching RefineKeyboard and demonstrates:

- completing the onboarding flow;
- opening iOS Settings and adding RefineKeyboard;
- enabling Allow Full Access, which is required for the keyboard extension to contact the AI service;
- switching to RefineKeyboard from a text field using the globe key;
- typing text and refining the complete draft;
- selecting part of a draft and refining only the selection;
- translating text;
- selecting a rewrite tone and creating a custom tone;
- viewing the subscription screen, including Restore Purchases, Privacy Policy, and Terms of Use.

RefineKeyboard does not support user accounts, registration, login, or account deletion. It does not publish user-generated content or provide a social/content feed.

### 2. Purpose, target audience, and value

RefineKeyboard is an AI-assisted iOS keyboard extension that helps people improve text directly inside messaging, email, and other apps. Users can correct grammar and clarity, change the tone of a message, shorten text, translate between supported languages, and listen to generated text. Its target audience is anyone who wants to communicate more clearly or confidently, including multilingual users and people who write frequent personal or professional messages.

The app solves the inconvenience of copying text into a separate writing or translation app. Its tools are available directly from the keyboard and run only after the user explicitly taps an AI action.

### 3. Setup and access instructions

No login credentials or sample files are required.

1. Launch RefineKeyboard and complete or skip the introductory screens.
2. Open **Settings → General → Keyboard → Keyboards → Add New Keyboard**.
3. Select **RefineKeyboard**.
4. Open RefineKeyboard in the keyboard list and enable **Allow Full Access**. iOS requires this permission because the extension makes a network request when the user invokes an AI feature.
5. Open any ordinary text field in an app such as Notes or Messages.
6. Touch and hold the globe key and select **RefineKeyboard**.
7. Type text. With no selected range, an AI action processes the complete current draft. If the user selects a text range, only that selected text is processed.
8. Tap **Refine**, **Translate**, or the AI panel to use the writing tools.

Five complimentary AI actions are provided. Continued AI use requires either the monthly or yearly auto-renewable subscription offered through Apple In-App Purchase. This is not an introductory subscription trial. The standard keyboard typing functions remain available without a subscription.

### 4. External services, tools, and platforms

- **OpenAI API:** AI text refinement, tone transformation, translation, and fallback text-to-speech.
- **Google Cloud Text-to-Speech:** speech generation for supported languages when available.
- **Render:** hosting for the RefineKeyboard backend API. The backend keeps service credentials outside the app and relays user-initiated requests.
- **Apple StoreKit / App Store:** monthly and yearly auto-renewable subscription purchases, entitlement verification, and purchase restoration.
- **Apple AVFoundation:** on-device playback of returned speech audio.

Text is transmitted only when the user explicitly invokes an AI or speech action. The app does not passively transmit keystrokes.

### 5. Regional differences

RefineKeyboard provides the same core functionality in all supported regions. Users can choose different output and translation languages, while subscription prices and storefront presentation are localized by the App Store. There are no region-specific feature restrictions imposed by the app.

### 6. Regulated industries and protected material

RefineKeyboard does not operate in a regulated industry and does not include or distribute protected third-party content. No special licenses or credentials are required.

Please let us know if any additional information is needed.

## Physical-device recording checklist

Record one continuous video on a physical device running the latest public iOS version:

- Start from the Home Screen and launch RefineKeyboard.
- Show all onboarding pages.
- Tap Open Settings.
- Add RefineKeyboard and enable Allow Full Access.
- Open Notes or Messages and switch keyboards using the globe key.
- Type at least two sentences.
- Use Refine with no selection and show that the whole draft is processed.
- Undo or type another two-sentence example, select one sentence, and show that only the selection is processed.
- Show Translate.
- Open the AI panel, choose a tone, and insert the result.
- Create a custom tone with a title and description; show both Use Once and the saved-tone behavior.
- Return to the host app and show the subscription screen, both plans, Restore Purchases, Privacy Policy, and Terms of Use.
- Do not show Xcode, debug controls, private API keys, notifications containing personal information, or unrelated personal conversations.

## Before uploading build 2

- Test the Release configuration on a physical iPhone and physical iPad.
- Confirm the production backend is reachable and all AI and speech actions succeed.
- Confirm both In-App Purchase products are in a submit-ready state and are submitted with app version 1.0.
- Confirm the App Store privacy answers disclose user content sent for app functionality and are consistent with the privacy policy.
- Upload new App Store screenshots showing the actual app and keyboard in use.
- Attach the physical-device recording in the Resolution Center reply.
- Paste the response above into both the reply and App Review Information notes.

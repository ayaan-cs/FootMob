# Security

FootMob is a read-only sports app. It has no accounts or login, no payments, no backend server, and no API keys. That keeps the attack surface small. This document covers what is left and how each part is protected.

## Threat model

| Entry point | Risk | Mitigation |
|---|---|---|
| `footmob://` deep links (any app or website can open them) | Injecting IDs into API paths; opening phishing pages inside the app | Game and team IDs must be 1–24 ASCII alphanumerics (`InputValidation.isValidIdentifier`). Article links must be HTTPS on `espn.com` / `espn.go.com`. Anything else is ignored. |
| Widget, Siri, Shortcuts and Control Center intent parameters | Same as deep links | The same validation in `TeamEntity.parsed` and `StartGameLiveActivityIntent`. `ESPNClient` validates again before building any URL. |
| ESPN API responses (third party, unauthenticated) | A tampered or odd payload loading tracking pixels or huge responses | Image URLs are kept only if HTTPS on `espncdn.com` / `espn.com`. Article links must be HTTPS. Responses are capped at 15 MB and images at 5 MB. Decoding is lenient but never evaluates content. |
| Network | Interception, downgrade, cookie leakage | ATS on with no exceptions. TLS 1.2 minimum. Ephemeral `URLSession` with no cookies, credential store or cache. |
| Web content (news articles) | Script access to app data, shared cookies | `SFSafariViewController` runs out of process and has no access to app data or cookies. Non-HTTPS links are refused. |
| Data on device | Reading cached files | Snapshots and images are written with `completeFileProtectionUntilFirstUserAuthentication`. Favorites are team names only, with no personal data. |
| On-device AI briefing | Prompt injection through headlines | The model's output is displayed as plain `Text`. It is never parsed into links, commands or intents. |

## Privacy

- No analytics, advertising SDKs, or third-party frameworks. The only dependency is Apple's SDKs.
- Nothing about the user is sent anywhere. Requests to ESPN carry no cookies or identifiers.
- `PrivacyInfo.xcprivacy` (in both the app and the widget extension) declares no tracking and no collected data.

## Keeping it secure

- Never commit signing certificates, provisioning profiles, `.p8` keys or tokens. The `.gitignore` excludes generated project files, and none of these are needed to run the app with a free Apple ID.
- If you switch to a paid data provider, don't put its API key in the app. Anything shipped in an app binary can be extracted. Put a small proxy in front of the provider and keep the key there.
- Run the tests (`swift test` in `Packages/FootMobKit`) after changing `InputValidation`. The suite includes hostile deep links and image URLs.

## Reporting a vulnerability

Please open a private security advisory on this GitHub repository instead of a public issue. Include steps to reproduce.

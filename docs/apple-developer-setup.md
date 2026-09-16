# Apple Developer / TestFlight bootstrap checklist

One-time browser steps to get the no-Mac pipeline (`app-ci.yml` →
`bootstrap-signing.yml` → `testflight.yml`) able to sign and ship the placeholder app to
your iPhone. You've already enrolled in the Apple Developer Program (confirmed in
`docs/PLAN.md`, Decisions §5), so this starts from creating the app record.

## 1. Create the App ID

[developer.apple.com](https://developer.apple.com) → Account → Certificates, IDs &
Profiles → Identifiers → **+**

- Bundle ID (explicit): `com.epavone.breviarium`
- Capabilities: none — the app makes no network calls and uses no push/background modes.

## 2. Create the App Store Connect app record

[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Apps → **+** → New App

- Platform: iOS
- Name: Breviarium (App Store Connect names are only visible to you until you actually
  submit for review, so this is fine even though the app stays private)
- Primary language: whatever you prefer for the App Store Connect UI — unrelated to the
  app's own Latin/English content
- Bundle ID: `com.epavone.breviarium` (from step 1)
- SKU: any unique string, e.g. `breviarium-ios`

## 3. Create an App Store Connect API key

App Store Connect → Users and Access → **Integrations** tab → **App Store Connect API** →
**Team Keys** → **+**

- Name: anything, e.g. "Breviarium CI"
- Access: **App Manager** (needed to upload builds and manage TestFlight)
- **Download the `.p8` file immediately** — App Store Connect only lets you download it
  once, right after creation.
- Note the **Key ID** and **Issuer ID** shown on that page — you'll need both.

## 4. Create the certificates storage repo

Create a new **private** GitHub repository, e.g. `ColdFrozenYeti/Breviarium-certificates`
(matches `App/fastlane/Matchfile` — rename both together if you'd rather use a different
name). Leave it empty; `fastlane match` populates it with encrypted certificates and
profiles the first time `bootstrap-signing.yml` runs. Nothing from `Breviarium` itself
goes in there.

Create a GitHub **fine-grained personal access token** scoped to only that repository,
with read/write access to its contents:
GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens →
**Generate new token**, repository access limited to `Breviarium-certificates`,
permissions: **Contents: Read and write**.

## 5. Add GitHub Actions secrets

On the `Breviarium` repo: Settings → Secrets and variables → Actions → **New repository
secret**, one for each of:

| Secret | Value |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | Key ID from step 3 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from step 3 |
| `APP_STORE_CONNECT_KEY_CONTENT` | The `.p8` file's contents, **base64-encoded** (e.g. `base64 -i AuthKey_XXXX.p8 \| pbcopy`-equivalent — on this machine, `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8")) \| Set-Clipboard` in PowerShell) |
| `MATCH_PASSWORD` | A passphrase you choose yourself — this encrypts everything match stores in the certificates repo. Save it somewhere durable (e.g. a password manager); losing it means regenerating certificates from scratch. |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `username:token` from step 4, **base64-encoded** (same encoding approach as above) |

## 6. Bootstrap signing

Repo → Actions tab → **Bootstrap signing** → Run workflow. This runs `fastlane match
appstore` on the macOS runner, creating the App Store distribution certificate and
provisioning profile and pushing them (encrypted) to the certificates repo. You should
only need to run this once, or again later if a certificate expires or needs replacing.

## 7. Ship the placeholder build

Repo → Actions tab → **TestFlight release** → Run workflow (or push a tag like `v0.0.1`).
This archives the placeholder app and uploads it via `fastlane pilot`.

## 8. Install on your iPhone

In App Store Connect → your app → TestFlight, add yourself as an internal tester if
you're not already listed (internal testers are anyone with a role on the app's App Store
Connect team — no external review needed). Install the **TestFlight** app from the App
Store on your iPhone, sign in with the same Apple ID, and the Breviarium build should
appear there once App Store Connect finishes processing it (usually a few minutes).

This completes M0's exit criterion: the placeholder app running on your iPhone via
TestFlight, proving the whole pipeline before any liturgical code depends on it.

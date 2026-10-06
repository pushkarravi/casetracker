# Agent Guide

Instructions for any coding agent or contributor (Codex, Claude Code, Cursor, humans). Keep this file tool-neutral: put shared rules here, not in tool-specific config.

## Project

Case Tracker is a native iOS app (SwiftUI + SwiftData, iOS 17+) that tracks USCIS case status by receipt number. Status comes from the official USCIS Case Status API (developer.uscis.gov) or from manual entry. No third-party dependencies.

## Commands

```bash
make build                          # build for the simulator
make test                           # run unit tests (Swift Testing)
make run                            # build, install, and launch in the simulator
make test SIMULATOR="iPhone 17"     # pick a different simulator
```

These wrap `xcodebuild`. Run `make test` before you consider a change done.

## Layout

```
CaseTracker/
  App/          app entry point, background-task wiring
  Models/       SwiftData models (TrackedCase, StatusEvent), receipt validation, status categories
  Services/     USCIS API client + parser, Keychain credentials, refresh logic, notifications, background refresh
  Views/        SwiftUI screens
  Info.plist    only the keys Xcode can't generate (background task IDs/modes)
CaseTrackerTests/  unit tests
```

## Conventions

- **Adding files:** the Xcode project uses folder-synchronized groups. Create `.swift` files under `CaseTracker/` or `CaseTrackerTests/` and they're compiled automatically. **Don't hand-edit `project.pbxproj`** to add files.
- **Build settings** live in `project.pbxproj`. Prefer `INFOPLIST_KEY_*` build settings over adding keys to `Info.plist`.
- **Tests** use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. Put parsing and state logic where it can be tested without the network (see `USCISResponseParser`, `CaseRefresher.apply`).
- **Never call the live API from tests.** Use JSON fixtures.
- **Secrets:** USCIS credentials are entered in-app and stored in the Keychain. Never commit API keys, and don't hardcode them.
- **Scraping:** don't add scraping of uscis.gov web pages. It's behind bot protection. Use the official API.
- **Style:** match the surrounding Swift: small types, `enum` namespaces for stateless helpers, and comments only where the *why* isn't obvious.

## USCIS API notes

- Auth: OAuth 2.0 client credentials, `POST {base}/oauth/accesstoken` (form-encoded `grant_type`, `client_id`, `client_secret`). Tokens last about 30 minutes.
- Status: `GET {base}/case-status/{receiptNumber}` with a Bearer token.
- Base URLs: sandbox `https://api-int.uscis.gov`, production `https://api.uscis.gov`.
- Sandbox limits: 5 requests per second and 1,000 a day. The test receipt is `EAC9999103402`.
- Response shape: see the doc comment in `CaseTracker/Services/USCISResponse.swift`.

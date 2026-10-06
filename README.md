# Case Tracker

A native iOS app for tracking USCIS immigration cases by receipt number.

- **Multiple cases** with nicknames, form type, and service center
- **Timeline** of every status change, imported from USCIS history and recorded as changes are detected
- **Automatic checks** through the official [USCIS Case Status API](https://developer.uscis.gov), on launch, on pull-to-refresh, and in the background every few hours
- **Notifications** when a case's status changes
- **Manual tracking** for cases you'd rather update yourself, or before you have API access

Not affiliated with USCIS.

## Requirements

- Xcode 16 or later. Built and tested with Xcode 27.
- iOS 17 or later

## Getting started

```bash
git clone https://github.com/pushkarravi/casetracker.git
cd casetracker
make test   # run unit tests
make run    # launch in the iOS Simulator
```

Or open `CaseTracker.xcodeproj` in Xcode and press Run. To run on a physical iPhone, pick your team under *Signing & Capabilities*.

## USCIS API access

Automatic status checks need credentials from the USCIS developer portal:

1. Create an account at [developer.uscis.gov](https://developer.uscis.gov) and register an app for the **Case Status API**.
2. Copy the **client ID** and **client secret** from the sandbox app.
3. In Case Tracker, open **Settings → USCIS API**, choose **Sandbox**, paste them in, and tap **Save and Test Connection**.
4. Add receipt `EAC9999103402` to see sandbox data.
5. When USCIS approves you for production, switch the environment to **Production** and enter the production keys.

Credentials are stored only in the device Keychain.

Without credentials you can still track cases manually. Turn off **Check automatically** when you add a case, then use **Add Update** to record status changes.

## Background checks

iOS schedules background refresh at its own discretion, based on how often you use the app and on battery state. The app requests a refresh about every 4 hours, but the actual timing varies. Opening the app checks any case not checked in the last 30 minutes.

To trigger a background refresh while debugging, pause the app in Xcode and run:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.pushkarravi.CaseTracker.refresh"]
```

## Contributing / AI agents

See [AGENTS.md](AGENTS.md) for layout, conventions, and commands. Any coding agent or human contributor can use it.

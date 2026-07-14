# Polar Coach Mac

Polar Coach is a first-pass native macOS dashboard for the fitness automation scripts that were previously run from the command line.

## What It Does

- Reads today's 2peak session from `~/Documents/Garmin/sync/twopeak_sessions.json`.
- Reads the latest MTI Polar GenX text file from `~/Documents/Garmin/sync`.
- Reads recent Strava activity from `~/Documents/Garmin/sync/strava_activities.json`.
- Shows freshness for Garmin, Strava, 2peak, MTI, and training-plan files.
- Shows the current morning brief if one has been generated.
- Provides sidebar buttons to run the existing sync scripts in `~/`.

## Launch

The app bundle is:

```text
PolarCoach.app
```

If macOS blocks it because it is unsigned, open it from Finder with Control-click, then Open.

## Build From Source

```bash
swift build
```

The Swift source is in:

```text
Sources/PolarCoachMac/main.swift
```

## Current Script Dependencies

The app does not copy credentials or secrets. It calls these existing scripts by absolute path:

- `/Users/patrickaltenburg/garmin_sync.py`
- `/Users/patrickaltenburg/strava_sync.py`
- `/Users/patrickaltenburg/twopeak_sync.py`
- `/Users/patrickaltenburg/twopeak_sessions_sync.py`
- `/Users/patrickaltenburg/mti_sync.py`
- `/Users/patrickaltenburg/calendar_sync.py`
- `/Users/patrickaltenburg/morning_brief.py`

The runner prefers `/opt/homebrew/bin/python3` and falls back to `/usr/bin/python3`.

## Important Security Note

Several of the original scripts contain live-looking API tokens, passwords, or bot credentials. Rotate those secrets before sharing this project or committing the old scripts anywhere. A next hardening pass should move secrets into Keychain, `.env`, or a private credentials file and remove them from source.

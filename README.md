# Polar Coach Apps

This repository contains the Polar Coach macOS and iOS apps.

## Projects

- `macOS/` - Swift Package macOS dashboard app for local training, recovery, and Morning Brief data.
- `iOS/` - Xcode iOS app that reads the shared Polar Coach snapshot and presents the mobile dashboard.

## Local Data

The apps expect Patrick's local training exports and generated files to live outside the repo, primarily under:

- `~/Documents/Garmin/sync`
- `~/Documents/health export`
- `~/Documents/polar_coach_snapshot.json`
- `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/polar_coach_snapshot.json`

Those data files are intentionally not committed here.

## Build

macOS:

```sh
cd macOS
swift build
```

iOS:

Open `iOS/PolarCoachiOS.xcodeproj` in Xcode and build/run the `PolarCoachiOS` target.


# Polar Coach iOS

Native SwiftUI iPhone companion app for the Polar Coach training dashboard.

## What This First Version Includes

- Red/yellow/green training readiness stoplight.
- AM and PM workout cards.
- Recovery section with Apple Health authorization.
- Weight, HRV, and resting heart-rate reads from HealthKit after permission is granted.
- Seven-day horizontal training calendar.
- Plain-text morning brief import using the toolbar import button.
- Sample data based on the current Mac Polar Coach dashboard.

## Open In Xcode

Open:

```text
PolarCoachiOS.xcodeproj
```

Then:

1. Select the `PolarCoachiOS` target.
2. Set your Apple developer team under **Signing & Capabilities**.
3. Confirm **HealthKit** is enabled.
4. Choose your iPhone or an iPhone simulator.
5. Press Run.

## How Data Works Right Now

The app starts with sample data. To bring in a generated brief:

1. Make sure the Mac app has generated `morning_brief_YYYY-MM-DD.txt`.
2. Put that file somewhere accessible to the iPhone, such as iCloud Drive.
3. In the iPhone app, tap the import icon in the top-right toolbar.
4. Pick the brief file.

The parser updates the stoplight, AM/PM cards, weight line, recovery note, recent load, and brief text from the imported file.

## Next Step

The clean next step is to have the Mac app save a small `polar_coach_snapshot.json` into iCloud Drive. The iPhone app can then import or automatically read that structured snapshot instead of parsing a text brief.

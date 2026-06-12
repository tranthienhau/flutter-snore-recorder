# Screenshot capture flow

Real captures from the iOS Simulator via an integration-test driver (no mockups).

## Steps

1. Boot the simulator:
   ```bash
   xcrun simctl boot "iPhone 17"
   open -a Simulator
   ```
2. Scaffold the iOS platform folder (lib-only project) and get dependencies:
   ```bash
   flutter create . --platforms=ios --project-name flutter_snore_recorder
   flutter pub get
   ```
3. Drive the screenshot test:
   ```bash
   flutter drive \
     --driver test_driver/integration_test.dart \
     --target integration_test/screenshot_test.dart \
     -d "iPhone 17"
   ```
4. Build the demo GIF from the PNGs:
   ```bash
   cd screenshots
   ffmpeg -y -framerate 1 -pattern_type glob -i '*.png' \
     -vf "scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
     -loop 0 demo.gif
   ```

PNGs + `demo.gif` are written to `screenshots/` and embedded in `README.md`.

## How it works

- `test_driver/integration_test.dart` - `integrationDriver(onScreenshot:)` writes each PNG to `screenshots/<name>.png`.
- `integration_test/screenshot_test.dart` - in `setUpAll` it calls `Hive.initFlutter()`, opens the `sleep_sessions` and `remedies` boxes, and seeds seven nights of realistic snore-tracking sessions (snore scores, snore counts, durations, tagged audio events) so every screen renders populated content instead of empty states.
- The test pumps the full `SnoreRecorderApp` (GoRouter + Riverpod), then navigates:
  - `01-home` - dashboard with last-night stats and the recent-nights list.
  - `02-history` - taps the history app-bar icon to show the snore-score trend chart.
  - `03-insights` - taps the insights app-bar icon to show key insights and remedies tracking.
  - `04-report` - taps the first night card to open its detailed sleep report.
- Each shot calls `binding.convertFlutterSurfaceToImage()` + `pumpAndSettle()` + `binding.takeScreenshot('NN-name')`.

# GridFlow example

Use the existing Flutter 3.47.5 stable SDK. GridFlow initializes the bundled
experimental windowing API at runtime; no SDK upgrade or channel change is
needed. See the [root README](../README.md) for bootstrap and runner details.

```sh
flutter pub get
flutter run -d macos
# Or: flutter run -d windows
```

Enable **Independent windows**, then open an app from the launcher. Its content
opens in a real OS window, sharing the same Flutter engine and Dart state.
The toggle affects future opens. Existing canvas windows keep their state.
Closing the launcher leaves independent windows running until the last closes.

The bootstrap initializes windowing for the launcher even when the switch is
off. Mobile and web keep using the canvas.

## Verification

```sh
# From the repository root:
flutter test
flutter analyze
# From example/:
flutter test
flutter build web
flutter run -d macos -t test_driver/windowing_smoke.dart
```

The native smoke test creates two independent windows, closes their launcher,
checks that the remaining windows survive, and verifies an in-memory result.
It prints `WINDOWING_SMOKE_OK` and exits when the final window closes.

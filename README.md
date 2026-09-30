<p align="center">
  <img 
    src="https://raw.githubusercontent.com/m1faridi/GridFlow/refs/heads/main/example/assets/screenshots/Screenshot%202026-01-07%20at%2010.11.11%E2%80%AFPM.png"
    width="900"
    alt="GridFlow Desktop Window Manager"
  />
</p>

# GridFlow – Desktop Window Manager for Flutter

A high-performance, OS-like **window management framework** for Flutter that enables **multi-window desktop experiences** inside a single application.

GridFlow provides a Flutter canvas with **runtime window spawning** and **window grouping**, plus optional independent OS windows using Flutter’s experimental Desktop Windowing API.

---

## ✨ Highlights

- **Configurable Window Chrome**  
  Control title bar visibility and behavior for each desktop session

- **Multi-Window UI**  
  Manage multiple independent windows inside a single Flutter app

- **Runtime Window Spawning**  
  Open new windows programmatically from any widget using `DesktopProvider`

- **Window Grouping**  
  Logically connect related windows via `connectionTag`

- **Parent–Child Windows**  
  Spawn child windows linked to a specific group or parent workflow

- **Auto-Start Applications**  
  Launch predefined windows automatically when desktop mode starts

- **Optional Title Bar**  
  Enable or disable window chrome depending on UX requirements

- **Platform-Agnostic**  
  Works on Desktop, Web, Tablet, and large-screen Android/iOS

- **Flutter-Native Rendering**  
  No platform channels, no native window manager dependency

---

## 🧠 Why GridFlow?

Flutter excels at cross-platform UI, but implementing a **true desktop-style, windowed interface** usually requires complex gesture handling, layout coordination, and state management.

GridFlow provides a clean and scalable abstraction for building:

- 📈 Trading dashboards with multiple charts and panels  
- 🛠 Admin / backoffice tools with detachable views  
- 🧩 Professional editors and IDE-like interfaces  
- 🖥 Kiosk and tablet applications requiring simultaneous panels  

---

## 📦 Installation

Add GridFlow to your `pubspec.yaml`:

```yaml
dependencies:
  grid_flow:
    git:
      url: https://github.com/m1faridi/GridFlow.git
```

Then run:

```bash
flutter pub get
```

## Independent windows (experimental Flutter API)

GridFlow uses Flutter's own `RegularWindowController`, `RegularWindow`, `ViewCollection` and
`runWidget` APIs. All windows run in **one Flutter engine and Dart isolate**.
This follows [Flutter's desktop windowing introduction](https://flutter.dev/blog/desktop-windowing-apis).

### SDK and setup

Use the existing **Flutter 3.47.5 stable** SDK (Dart 3.13.4). No channel switch or
SDK upgrade is needed. This version bundles the experimental API under the
`RegularWindowController` / `RegularWindow` names. The article uses names from a
newer main revision; this integration intentionally targets the installed SDK.

```bash
cd example
flutter pub get
flutter run -d macos
# Or: flutter run -d windows
```

On this stable SDK, `flutter config --enable-windowing` and the equivalent
pubspec setting do not enable the API. `GridNativeWindows.ensureInitialized()`
opts in through Flutter's internal runtime flag and installs the native
windowing owner. `GridNativeWindows.run(...)` calls it automatically, and it
also works if `WidgetsFlutterBinding.ensureInitialized()` has already run.
This is an experimental, application-local opt-in; it does not edit the Flutter
SDK or global settings. Internal API compatibility with other SDK versions is
not guaranteed.

The macOS and Windows runners start a single engine without a native launcher
window. Dart creates the launcher and every subsequent window, so initialize
windowing even when the **Independent windows** switch is off. The bootstrap
handles this automatically. Mobile and web continue to use the canvas.

### Bootstrap

Replace `runApp(...)` or the old `GridNativeWindows.initialize(...)` bootstrap
with `GridNativeWindows.run(...)`:

```dart
void main() {
  GridNativeWindows.run(
    MaterialApp(
      home: GridDesktop(
        useNativeWindows: true,
        apps: [
          DesktopApp(
            title: 'Editor',
            nativeWindowSize: const Size(900, 700),
            contentBuilder: (_) => Editor(documentId: 'document-42'),
          ),
        ],
      ),
    ),
    title: 'My workspace',
    // Optional: theme/localizations for each additional native window.
    appBuilder: (child) => MaterialApp(home: child),
  );
}
```

`Editor` is your application widget. The same `contentBuilder` works on the
canvas and in native windows, including captured services and model objects.
For a separate native presentation, optionally register `builders` in `run`
and select one using `DesktopApp.nativeId`. That builder receives
`NativeWindowLaunch`, including `windowId`, `parentId` and `nativeArguments`.
Arguments and close results are ordinary Dart values and need no serialization.
An unknown explicit `nativeId` is reported as an error.

Set `GridDesktop(useNativeWindows: true)` to open **new** apps in independent OS
windows on macOS, Windows and Linux. The default is `false`. Changing this
option leaves existing windows in their current mode. Mobile and web use the
canvas. A GridDesktop mounted without the native bootstrap also keeps using
the canvas when its runner provides an implicit view.

`DesktopProvider.of(context)?.openApp(...)` works in both modes. In a native
window, further opens are native too. The returned future receives
`closeApp(result)`; closing with the OS button returns `null`.
`isClosable: false` ignores OS close requests; programmatic closure still works.
The OS may still draw an enabled close button because the experimental API
does not expose a close-button visibility/enabled setting.

Removing `GridDesktop` leaves native windows alive. Closing the launcher or an
opener also leaves its independent windows alive; the application exits when
the last window closes. OS-level Quit exits the entire application. Removing the
root `GridNativeWindowHost` releases all windows and completes pending results.
Native title bars, resizing, minimizing and maximizing belong to the OS.
Canvas snapping, connection lines and zoom only apply to embedded windows.

### Shared inherited state

Captured objects are shared directly. To share Provider, Riverpod, Bloc or your
own inherited state across views, place its scope **above** the root host:

```dart
void main() {
  GridNativeWindows.ensureInitialized();
  runWidget(
    MySharedProviders(
      child: GridNativeWindowHost(
        launcher: MaterialApp(home: MyDesktop()),
        appBuilder: (child) => MaterialApp(home: child),
      ),
    ),
  );
}
```

`MySharedProviders` and `MyDesktop` stand for your app's widgets. This explicit
`runWidget` form is for desktop; initialize the bundled API first as shown. Each window has
its own MaterialApp/Navigator. Providers placed *inside* the launcher's
MaterialApp are local to that window.

### Native runner migration

The old per-window plugin callbacks are removed. Apps consuming GridFlow must
also update their runners, not just their Dart entrypoint:

- **macOS:** retain a `FlutterEngine` in `AppDelegate`, run it, and register
  plugins once with that engine. Remove the `MainFlutterWindow` object and its
  outlet from `MainMenu.xib`. See the runnable example's
  [`AppDelegate.swift`](example/macos/Runner/AppDelegate.swift).
- **Windows:** create and run one `flutter::FlutterEngine`, register plugins,
  and keep the message loop. Run the UI isolate on the platform thread.
  See [`main.cpp`](example/windows/runner/main.cpp).
- **Linux:** run the UI isolate on the platform thread. The root repository's
  runner retains its original hidden view to own the engine; only Dart-created
  windows render frames. The example does not yet include a Linux runner.

Rebuild fully after changing runners. No third-party window-management plugin
or per-window engine/plugin registration is needed.

## 🚀 Quick Start

### 1) Create a Desktop Container

```dart
GridDesktop(
  isWindowMode: true,
  hasTitleBar: true,

  autoStartApps: [
    DesktopApp(
      title: "Auto App",
      color: Colors.purple,
      isClosable: false,
      contentBuilder: (id) => const MyApp2(),
    ),
  ],

  apps: [
    DesktopApp(
      title: "Camera Input",
      color: Colors.blue,
      connectionTag: "group_1",
      contentBuilder: (id) => const MyApp2(),
    ),
    DesktopApp(
      title: "Save Output",
      color: Colors.green,
      connectionTag: "group_2",
    ),
    DesktopApp(
      title: "Music Player",
      color: Colors.red,
      connectionTag: "audio_system",
    ),
    DesktopApp(
      title: "Equalizer",
      color: Colors.orange,
      connectionTag: "audio_system",
    ),
  ],
)
```

### 2) Open New Windows at Runtime (Child Windows)

Any window can spawn new windows dynamically using `DesktopProvider`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyApp2 extends StatelessWidget {
  const MyApp2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(CupertinoIcons.add_circled),
          label: const Text("Open New Window"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () {
            DesktopProvider.of(context)?.openApp(
              DesktopApp(
                title: "Child Window",
                color: Colors.teal,
                connectionTag: "group_1",
                contentBuilder: (id) => const MyApp2(),
              ),
              parentId: "group_1",
            );
          },
        ),
      ),
    );
  }
}
```

### 3) Await window result

```dart
final result = await DesktopProvider.of(context)?.openApp(
  DesktopApp(
    title: "Child Window",
    color: Colors.teal,
    connectionTag: "group_1",
    contentBuilder: (id) => const MyApp2(),
  ),
  parentId: "group_1",
);

debugPrint("Window closed with result: $result");

DesktopProvider.of(context)?.closeApp("return");
```

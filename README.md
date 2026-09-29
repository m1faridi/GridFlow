<p align="center">
  <img 
    src="https://raw.githubusercontent.com/m1faridi/GridFlow/refs/heads/main/example/assets/screenshots/Screenshot%202026-01-07%20at%2010.11.11%E2%80%AFPM.png"
    width="900"
    alt="GridFlow Desktop Window Manager"
  />
</p>

# GridFlow – Desktop Window Manager for Flutter

A high-performance, OS-like **window management framework** for Flutter that enables **multi-window desktop experiences** inside a single application.

GridFlow provides a Flutter canvas with **runtime window spawning** and **window grouping**, plus optional independent OS windows on macOS and Windows.

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

## Independent macOS and Windows windows

Set `GridDesktop(useNativeWindows: true, ...)` to open **new** apps in real OS
windows. The default is `false`. Android, iOS, Linux and web keep using the canvas.
Changing this option does not move existing windows between modes.

Each native window has its own Flutter engine. Register builders in `main()` so
every engine can reconstruct its content, and give custom apps a stable
`nativeId`. The initialization returns a child app when running in a new window;
run that app instead of creating another launcher:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final nativeApp = await GridNativeWindows.initialize(
    builders: {
      'editor': (launch) => Editor(documentId: launch.arguments['documentId']),
    },
    // Optional: set the child's theme, localization and app-level providers.
    appBuilder: (child) => MaterialApp(home: child),
  );
  runApp(nativeApp ?? MaterialApp(
    home: GridDesktop(
      useNativeWindows: true,
      apps: [
        DesktopApp(
          title: 'Editor',
          nativeId: 'editor',
          nativeArguments: {'documentId': 'document-42'},
          nativeWindowSize: const Size(900, 700),
          contentBuilder: (_) => Editor(documentId: 'document-42'),
        ),
      ],
    ),
  ));
}
```

`Editor` is your app widget. `contentBuilder` supplies the canvas version;
the registered native builder supplies the independent version. Apps without
custom content can omit `nativeId` and use the default title-only view.
Initial arguments must be JSON-serializable. Providers, in-memory objects and
captured closures from the launcher are not shared; initialize services in every
engine or synchronize data through your application's storage/IPC layer.
Separate engines use more memory; this mode does not promise lower total CPU use.

`DesktopProvider.of(context)?.openApp(...)` works inside both types of windows.
Inside a native window, further opens are native too. Its returned future receives
the value passed to `closeApp(result)`; closing with the OS button returns `null`.
Results must be supported by Flutter's standard method codec (for example strings,
numbers, lists and maps). `isClosable: false` disables the OS close action;
programmatic `closeApp` can still finish the window.

Removing the `GridDesktop` widget leaves native windows alive. Closing the main
OS window hides its launcher while other windows are open, then closes it when
the last child closes. OS-level **Quit** still exits the whole application.
Native controls, resizing, minimizing and maximizing are provided by the OS;
canvas snapping, linking lines and canvas zoom apply to embedded windows only.

### Register plugins in each native window

The repository's runners and runnable example already include this setup.
Applications consuming GridFlow must also add the following callbacks. A full
rebuild is required after adding plugins; hot reload is insufficient.

In `macos/Runner/MainFlutterWindow.swift`, import `desktop_multi_window` and add
this immediately after the existing `RegisterGeneratedPlugins` call:

```swift
FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
  RegisterGeneratedPlugins(registry: controller)
}
```

In `windows/runner/flutter_window.cpp`, add
`#include "desktop_multi_window/desktop_multi_window_plugin.h"`, then add this
immediately after the existing `RegisterPlugins` call in `OnCreate()`:

```cpp
DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
  auto* view = reinterpret_cast<flutter::FlutterViewController*>(controller);
  RegisterPlugins(view->engine());
});
```

The implementation uses [desktop_multi_window](https://pub.dev/packages/desktop_multi_window)
and [window_manager](https://pub.dev/packages/window_manager). Verify that any
additional plugins in your child apps support multiple Flutter engines.

Run `flutter run -d macos` or `flutter run -d windows` from `example/` and enable
the **Native windows** switch to try it. The switch affects the next window you open.

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

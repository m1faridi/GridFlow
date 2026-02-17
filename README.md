<p align="center">
  <img 
    src="https://raw.githubusercontent.com/m1faridi/GridFlow/refs/heads/main/example/assets/screenshots/Screenshot%202026-01-07%20at%2010.11.11%E2%80%AFPM.png"
    width="900"
    alt="GridFlow Desktop Window Manager"
  />
</p>

# GridFlow – Desktop Window Manager for Flutter

A high-performance, OS-like **window management framework** for Flutter that enables **multi-window desktop experiences** inside a single application.

GridFlow allows you to build draggable, window-based UIs with **runtime window spawning** and **window grouping** — all rendered purely in Flutter with no native dependencies.

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

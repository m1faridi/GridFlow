# Grid Desktop for Flutter
A high-performance, OS-like **window manager** for Flutter that enables **multi-window desktop experiences** inside a single app.  
Build draggable, resizable, and snappable windows with **runtime window spawning**, **window grouping**, and **mobile ↔ desktop mode switching** — all rendered purely in Flutter.

---

## Highlights

- **Desktop / Window Mode Toggle**: switch between mobile layout and windowed desktop layout at runtime
- **Multi-Window UI**: manage many independent windows on one screen
- **Runtime Window Spawning**: open new windows from anywhere via `DesktopProvider`
- **Window Grouping**: logically connect windows using `connectionTag` (e.g., audio system, pipeline stages)
- **Parent–Child Windows**: open windows as children of a group or parent context
- **Auto-Start Apps**: boot predefined windows automatically on launch
- **Optional Title Bar**: enable/disable window chrome depending on your UX
- **Platform-Agnostic**: Desktop, Web, Tablet, and large-screen Android/iOS
- **Flutter-Native Rendering**: no platform channels, no native window manager dependency

---

## Why This Package

Flutter excels at cross-platform UI, but building a true desktop-like, windowed experience (similar to an OS desktop) typically requires custom state management and heavy gesture/UI logic.

This library provides a clean framework to:
- build **Trading dashboards** with multiple panels/windows
- create **Admin/Backoffice** tools with detachable views
- implement **Professional editors** and **IDE-like** interfaces
- support **Kiosk/Tablet** workflows that require multi-panel visibility

---

## Installation

Add the package to your `pubspec.yaml` (replace with your repo package name):

```yaml
dependencies:
  GridFlow: ^0.0.1


Quick Start
1) Create a Desktop Container


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

2) Open New Windows at Runtime (Child Windows)

Any window can spawn new windows using DesktopProvider:


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



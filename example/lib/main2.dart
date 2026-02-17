import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:grid_flow/grid_os.dart';

class MyApp2 extends StatelessWidget {

  const MyApp2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(CupertinoIcons.add_circled),
              label: const Text("Open New Window"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                // --- اینجا جادو اتفاق می‌افتد ---
                // استفاده از Provider برای دسترسی به متد openApp در GridDesktop
                DesktopProvider.of(context)?.openApp(
                  DesktopApp(
                    title: "Child Window",
                    color: Colors.teal,
                    connectionTag: "group_1",

                    // این پنجره جدید هم می‌تواند دوباره MyApp2 را باز کند (بازگشتی)
                    contentBuilder: (id) => MyApp2(),

                    // اگر می‌خواهید این پنجره جدید هم به قبلی وصل شود، تگ یکسان بدهید
                    // connectionTag: "group_1",
                  ),
                  parentId: "group_1", // لینک کردن به پنجره مادر
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

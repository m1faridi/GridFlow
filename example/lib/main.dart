import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:grid_flow/grid_os.dart';
// ایمپورت کردن کتابخانه خودتان


void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Grid OS Library Test',
    home: MyDesktop(),
  ));
}

class MyDesktop extends StatelessWidget {
  const MyDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return GridDesktop(
      apps: [
        DesktopApp(
          title: "Master App",
          icon: CupertinoIcons.layers_alt,
          color: Colors.cyan,
          // محتوای سفارشی (اختیاری)
          contentBuilder: (id) => Center(child: Text("This is Master App ID: $id")),
        ),
        DesktopApp(
          title: "Files",
          icon: CupertinoIcons.folder_fill,
          color: Colors.orange,
        ),
        DesktopApp(
          title: "Settings",
          icon: CupertinoIcons.settings,
          color: Colors.grey,
          contentBuilder: (id) => const Center(child: Icon(Icons.settings, size: 50)),
        ),
      ],
    );
  }
}
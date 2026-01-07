import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'grid_os.dart';
import 'main2.dart'; // فایل main2 را ایمپورت کنید

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Grid OS',
    home: MyDesktop(),
  ));

}

class MyDesktop extends StatelessWidget {
  const MyDesktop({super.key});




  @override
  Widget build(BuildContext context) {
    return GridDesktop(
      autoStartApps: [
        DesktopApp(
          title: "Auto App", // تیتر پنجره
          icon: CupertinoIcons.bolt, // آیکون پنجره (بالا سمت چپ پنجره)
          color: Colors.purple,
          isClosable: false,
          hasTitleBar: false,
          contentBuilder: (id) => const MyApp2(),
        ),
      ],
      apps: [
        // --- گروه اول ---
        DesktopApp(
          title: "Camera Input",
          icon: CupertinoIcons.camera,
          color: Colors.blue,
          connectionTag: "group_1",
          // اتصال MyApp2 به این پنجره
          // ما ID پنجره را به MyApp2 پاس می‌دهیم تا بتواند از آن استفاده کند
          contentBuilder: (id) => MyApp2(),
        ),
        DesktopApp(
          title: "Save Output",
          icon: CupertinoIcons.floppy_disk,
          color: Colors.green,
          connectionTag: "group_2",
        ),

        // --- گروه دوم ---
        DesktopApp(
          title: "Music Player",
          icon: CupertinoIcons.music_note_2,
          color: Colors.red,
          connectionTag: "audio_system",
        ),
        DesktopApp(
          title: "Equalizer",
          icon: CupertinoIcons.slider_horizontal_3,
          color: Colors.orange,
          connectionTag: "audio_system",
        ),
      ],
    );
  }
}
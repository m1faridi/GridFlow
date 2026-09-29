import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grid_flow/grid_os.dart';
import 'main2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final nativeApp = await GridNativeWindows.initialize(
    builders: {'demo': (_) => const MyApp2()},
  );
  if (nativeApp != null) {
    runApp(nativeApp);
    return;
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grid OS',
      home: MyDesktop(),
    ),
  );
}

class MyDesktop extends StatefulWidget {
  const MyDesktop({super.key});

  @override
  State<MyDesktop> createState() => _MyDesktopState();
}

class _MyDesktopState extends State<MyDesktop> {
  bool _useNativeWindows = false;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      GridDesktop(
        useNativeWindows: _useNativeWindows,
        autoStartApps: [
          DesktopApp(
            title: 'Auto App',
            color: Colors.purple,
            isClosable: false,
            nativeId: 'demo',
            contentBuilder: (_) => const MyApp2(),
          ),
        ],
        apps: [
          DesktopApp(
            title: 'Camera Input',
            color: Colors.blue,
            connectionTag: 'group_1',
            nativeId: 'demo',
            contentBuilder: (_) => const MyApp2(),
          ),
          DesktopApp(
            title: 'Save Output',
            color: Colors.green,
            connectionTag: 'group_2',
          ),
          DesktopApp(
            title: 'Music Player',
            color: Colors.red,
            connectionTag: 'audio_system',
          ),
          DesktopApp(
            title: 'Equalizer',
            color: Colors.orange,
            connectionTag: 'audio_system',
          ),
        ],
      ),
      if (GridNativeWindows.isSupported)
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: Material(
              color: const Color(0xFF252A32),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Native windows',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _useNativeWindows,
                      onChanged: (value) =>
                          setState(() => _useNativeWindows = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

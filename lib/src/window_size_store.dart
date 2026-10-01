import 'dart:async';
import 'dart:convert';

import 'package:data_save/DataSave.dart';
import 'package:flutter/widgets.dart';

/// Remembers normal window sizes, independently for canvas and native windows.
class WindowSizeStore {
  WindowSizeStore(this.mode);

  final String mode;
  Future<void>? _initialization;
  Future<void> _writes = Future.value();
  final Map<String, Size> _pending = {};
  Timer? _timer;

  String _key(String name) =>
      'grid_flow.window_size.v1.$mode.${Uri.encodeComponent(name)}';

  static bool isValid(Size size) =>
      size.isFinite && size.width >= 200 && size.height >= 150;

  Future<Size?> read(String name) async {
    try {
      await (_initialization ??= DataSave.init());
      await _writes;
      if (_pending.containsKey(name)) return _pending[name];
      final raw = DataSave.getString(_key(name));
      if (raw == null) return null;
      final value = jsonDecode(raw);
      if (value is! List ||
          value.length != 2 ||
          value[0] is! num ||
          value[1] is! num) {
        return null;//
      }
      final size = Size(
        (value[0] as num).toDouble(),
        (value[1] as num).toDouble(),
      );
      return isValid(size) ? size : null;
    } catch (error) {
      _initialization = null;
      debugPrint('GridFlow could not read a saved window size: $error');
      return null;
    }
  }

  void save(String name, Size size) {
    if (!isValid(size)) return;
    _pending[name] = size;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), flush);
  }

  Future<void> flush() {
    _timer?.cancel();
    final values = Map<String, Size>.of(_pending);
    _pending.clear();
    _writes = _writes.then((_) async {
      if (values.isEmpty) return;
      try {
        await (_initialization ??= DataSave.init());
        for (final entry in values.entries) {
          await DataSave.setString(
            _key(entry.key),
            jsonEncode([entry.value.width, entry.value.height]),
          );
        }
      } catch (error) {
        _initialization = null;
        debugPrint('GridFlow could not save a window size: $error');
      }
    });
    return _writes;
  }
}

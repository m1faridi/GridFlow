import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:grid_flow/grid_os.dart';

class MyApp2 extends StatefulWidget {
  const MyApp2({super.key});

  @override
  State<MyApp2> createState() => _MyApp2State();
}

class _MyApp2State extends State<MyApp2> {
  final Random _random = Random();

  static const List<String> _titles = [
    'Workflow Monitor',
    'Insight Board',
    'Node Controller',
    'Live Operations',
    'Signal Tracker',
    'Command Center',
  ];

  static const List<String> _subtitles = [
    'Realtime queue and health overview',
    'Randomized demo data for stress test',
    'Multiple widgets living in one window',
    'Window-to-window workflow simulation',
    'Dynamic list, colors, and actions',
    'Desktop mode interaction playground',
  ];

  static const List<String> _itemNames = [
    'Render Pipeline',
    'Audio Bridge',
    'Stream Worker',
    'Scene Cache',
    'Upload Channel',
    'Output Guard',
    'Graph Resolver',
    'Metrics Collector',
    'Sync Agent',
    'Backup Node',
  ];

  static const List<Color> _palette = [
    // Blue Spectrum
    Color(0xFF2563EB),
    Color(0xFF1D4ED8),
    Color(0xFF3B82F6),
    Color(0xFF60A5FA),

    // Orange / Amber
    Color(0xFFEA580C),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFFFB923C),

    // Green Spectrum
    Color(0xFF059669),
    Color(0xFF10B981),
    Color(0xFF16A34A),
    Color(0xFF22C55E),

    // Red / Rose
    Color(0xFFDC2626),
    Color(0xFFBE123C),
    Color(0xFFE11D48),
    Color(0xFFEF4444),

    // Purple / Violet
    Color(0xFF7C3AED),
    Color(0xFF6D28D9),
    Color(0xFF8B5CF6),
    Color(0xFFA78BFA),

    // Teal / Cyan
    Color(0xFF0F766E),
    Color(0xFF14B8A6),
    Color(0xFF0891B2),
    Color(0xFF06B6D4),

    // Pink / Magenta
    Color(0xFFDB2777),
    Color(0xFFEC4899),
    Color(0xFFF472B6),

    // Neutral / Accent
    Color(0xFF334155),
    Color(0xFF475569),
    Color(0xFF64748B),
    Color(0xFF94A3B8),
  ];


  late Color _themeColor;
  late String _title;
  late String _subtitle;
  late List<_DemoEntry> _entries;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    _themeColor = _palette[_random.nextInt(_palette.length)];
    _title = _titles[_random.nextInt(_titles.length)];
    _subtitle = _subtitles[_random.nextInt(_subtitles.length)];

    _entries = List.generate(8, (index) {
      final name = _itemNames[_random.nextInt(_itemNames.length)];
      final progress = 20 + _random.nextInt(80);
      final isHealthy = _random.nextBool();
      return _DemoEntry(
        name: '$name #${index + 1}',
        description: isHealthy ? 'Operational and stable' : 'Needs attention',
        progress: progress,
        healthy: isHealthy,
      );
    });
  }

  Future<void> _openWindow() async {
    final desktop = DesktopProvider.of(context);
    if (desktop == null) return;

    final childTitle = '${_titles[_random.nextInt(_titles.length)]} ${100 + _random.nextInt(900)}';
    final childColor = _palette[_random.nextInt(_palette.length)];

    final result = await desktop.openApp(
      DesktopApp(
        title: childTitle,
        color: childColor,
        connectionTag: 'group_1',
        contentBuilder: (_) => const MyApp2(),
      ),
      parentId: 'group_1',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 900),
        content: Text('Window result: ${result ?? "none"}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Color.alphaBlend(
      _themeColor.withValues(alpha: 0.18),
      const Color(0xFF0B1220),
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _openWindow,
                          icon: const Icon(CupertinoIcons.add_circled, size: 18),
                          label: const Text('Open New Window'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _themeColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(_regenerate),
                          icon: const Icon(CupertinoIcons.refresh),
                          label: const Text('Regenerate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_entries.length} items',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _entries[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                item.healthy ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_triangle_fill,
                                size: 16,
                                color: item.healthy ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.progress}%',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.description,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: item.progress / 100,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(_themeColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    DesktopProvider.of(context)?.closeApp({
                      'title': _title,
                      'items': _entries.length,
                    });
                  },
                  icon: const Icon(CupertinoIcons.check_mark_circled),
                  label: const Text('Close & Return Result'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoEntry {
  final String name;
  final String description;
  final int progress;
  final bool healthy;

  const _DemoEntry({
    required this.name,
    required this.description,
    required this.progress,
    required this.healthy,
  });
}

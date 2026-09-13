import 'package:flutter/material.dart';

class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static const List<Map<String, String>> _shortcuts = [
    {'key': 'Space', 'desc': 'Play / Pause'},
    {'key': '→', 'desc': 'Next track'},
    {'key': '←', 'desc': 'Previous track'},
    {'key': '↑', 'desc': 'Volume up (+10%)'},
    {'key': '↓', 'desc': 'Volume down (-10%)'},
    {'key': 'M', 'desc': 'Toggle mute'},
    {'key': 'S', 'desc': 'Open Sleep Timer'},
    {'key': 'E', 'desc': 'Open Equalizer'},
    {'key': 'D', 'desc': 'Open Download / Cache'},
    {'key': '?', 'desc': 'Show shortcuts dialog'},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.keyboard_outlined, color: Color(0xFF1DB954)),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Keyboard Shortcuts',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF282828), height: 1),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              itemCount: _shortcuts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _shortcuts[index];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['desc']!,
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF3E3E3E)),
                      ),
                      child: Text(
                        item['key']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

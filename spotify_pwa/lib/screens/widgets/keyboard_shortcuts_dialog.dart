import 'package:flutter/material.dart';

enum _ShortcutMode { phone, pc }

class KeyboardShortcutsDialog extends StatefulWidget {
  const KeyboardShortcutsDialog({super.key});

  @override
  State<KeyboardShortcutsDialog> createState() => _KeyboardShortcutsDialogState();
}

class _KeyboardShortcutsDialogState extends State<KeyboardShortcutsDialog>
    with SingleTickerProviderStateMixin {
  _ShortcutMode _mode = _ShortcutMode.phone;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  static const _pcShortcuts = <Map<String, String>>[
    {'key': 'Space', 'desc': 'Play / Pause'},
    {'key': '→', 'desc': 'Next track'},
    {'key': '←', 'desc': 'Previous track'},
    {'key': '↑', 'desc': 'Volume up (+10%)'},
    {'key': '↓', 'desc': 'Volume down (-10%)'},
    {'key': 'M', 'desc': 'Toggle mute'},
    {'key': 'S', 'desc': 'Open Sleep Timer'},
    {'key': 'E', 'desc': 'Open Equalizer'},
    {'key': 'D', 'desc': 'Open Downloads'},
    {'key': '?', 'desc': 'Show shortcuts'},
  ];

  // Phone gestures: desc + key label + optional note
  static const _phoneShortcuts = <Map<String, String>>[
    {
      'key': '← Back',
      'desc': 'Navigate back in Spotify',
      'note': 'System back gesture / button — stays in app',
    },
    {
      'key': 'Swipe ←',
      'desc': 'Next track',
      'note': 'Swipe left on the player area',
    },
    {
      'key': 'Swipe →',
      'desc': 'Previous track',
      'note': 'Swipe right on the player area',
    },
    {
      'key': 'Swipe ↓',
      'desc': 'Open Quick Tools',
      'note': 'Swipe down anywhere on screen',
    },
    {
      'key': '⚙ Tap',
      'desc': 'Open Quick Tools panel',
      'note': 'Tap the floating ⚙ button (drag to reposition)',
    },
    {
      'key': 'Vol +/–',
      'desc': 'System volume',
      'note': 'Hardware volume buttons',
    },
    {
      'key': 'Hold Vol+',
      'desc': 'Next track',
      'note': 'Long-press the volume-up hardware key',
    },
    {
      'key': 'Hold Vol–',
      'desc': 'Previous track',
      'note': 'Long-press the volume-down hardware key',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _switchMode(_ShortcutMode mode) {
    if (mode == _mode) return;
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() => _mode = mode);
        _animController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = _mode == _ShortcutMode.phone;
    final shortcuts = isPhone ? _phoneShortcuts : _pcShortcuts;

    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 10, 0),
              child: Row(
                children: [
                  Icon(
                    isPhone ? Icons.smartphone : Icons.keyboard_outlined,
                    color: const Color(0xFF1DB954),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPhone ? 'Phone Shortcuts & Gestures' : 'PC / Desktop Shortcuts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Mode toggle pills
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeTab(
                        _ShortcutMode.phone,
                        Icons.smartphone,
                        'Phone',
                      ),
                    ),
                    Expanded(
                      child: _buildModeTab(
                        _ShortcutMode.pc,
                        Icons.keyboard_alt_outlined,
                        'PC / Desktop',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(color: Color(0xFF2A2A2A), height: 1),

            // Shortcuts list
            Flexible(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  shrinkWrap: true,
                  itemCount: shortcuts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, i) => _buildShortcutRow(shortcuts[i], isPhone),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(_ShortcutMode mode, IconData icon, String label) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1DB954) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF191414) : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF191414) : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutRow(Map<String, String> item, bool isPhone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['desc']!,
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isPhone && item['note'] != null && item['note']!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item['note']!,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFF1DB954).withAlpha(100)),
            ),
            child: Text(
              item['key']!,
              style: const TextStyle(
                color: Color(0xFF1DB954),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

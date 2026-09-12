import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../services/equalizer_service.dart';
import '../../services/sleep_timer_service.dart';
import '../../services/cache_manager_service.dart';
import 'equalizer_modal.dart';
import 'sleep_timer_modal.dart';
import 'cache_manager_modal.dart';
import 'keyboard_shortcuts_dialog.dart';

class SettingsBottomSheet extends StatelessWidget {
  final EqualizerService equalizerService;
  final SleepTimerService sleepTimerService;
  final CacheManagerService cacheManagerService;
  final InAppWebViewController? webViewController;
  final VoidCallback? onReloadRequested;

  const SettingsBottomSheet({
    super.key,
    required this.equalizerService,
    required this.sleepTimerService,
    required this.cacheManagerService,
    this.webViewController,
    this.onReloadRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          const Row(
            children: [
              Icon(Icons.settings_outlined, color: Color(0xFF1DB954), size: 24),
              SizedBox(width: 10),
              Text(
                'App Settings & Tools',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Equalizer Tile
          ListenableBuilder(
            listenable: equalizerService,
            builder: (context, _) {
              final preset = equalizerService.selectedPresetId.toUpperCase();
              final isEnabled = equalizerService.isEnabled;

              return _buildSettingsTile(
                context: context,
                icon: Icons.equalizer,
                title: 'Audio Equalizer',
                subtitle: isEnabled ? 'Active Preset: $preset' : 'Disabled',
                badgeText: isEnabled ? preset : 'OFF',
                badgeColor: isEnabled ? const Color(0xFF1DB954) : Colors.grey,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => EqualizerModal(equalizerService: equalizerService),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),

          // Sleep Timer Tile
          ListenableBuilder(
            listenable: sleepTimerService,
            builder: (context, _) {
              final state = sleepTimerService.state;
              final isActive = state.isActive;

              return _buildSettingsTile(
                context: context,
                icon: Icons.bedtime_outlined,
                title: 'Sleep Timer',
                subtitle: isActive
                    ? 'Stops playback in ${state.formattedRemaining}'
                    : 'Turn off audio automatically',
                badgeText: isActive ? state.formattedRemaining : null,
                badgeColor: Colors.orangeAccent,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => SleepTimerModal(sleepTimerService: sleepTimerService),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),

          // Downloads & Storage Tile
          ListenableBuilder(
            listenable: cacheManagerService,
            builder: (context, _) {
              final cache = cacheManagerService.cacheInfo;

              return _buildSettingsTile(
                context: context,
                icon: Icons.download_for_offline_outlined,
                title: 'Downloads & Storage Cache',
                subtitle: 'Offline streams, assets & cache cleaner',
                badgeText: cache.formattedTotal,
                badgeColor: const Color(0xFF1DB954),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CacheManagerModal(
                      cacheManagerService: cacheManagerService,
                      webViewController: webViewController,
                      onOfflineModeChanged: onReloadRequested,
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),

          // Keyboard Shortcuts Tile
          _buildSettingsTile(
            context: context,
            icon: Icons.keyboard_outlined,
            title: 'Keyboard Shortcuts',
            subtitle: 'External keyboard & media keys support',
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => const KeyboardShortcutsDialog(),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF242424),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF1DB954), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? const Color(0xFF1DB954)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (badgeColor ?? const Color(0xFF1DB954)).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor ?? const Color(0xFF1DB954),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

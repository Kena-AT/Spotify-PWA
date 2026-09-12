import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../services/cache_manager_service.dart';

class CacheManagerModal extends StatelessWidget {
  final CacheManagerService cacheManagerService;
  final InAppWebViewController? webViewController;
  final VoidCallback? onOfflineModeChanged;

  const CacheManagerModal({
    super.key,
    required this.cacheManagerService,
    this.webViewController,
    this.onOfflineModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cacheManagerService,
      builder: (context, _) {
        final cache = cacheManagerService.cacheInfo;
        final isCalculating = cacheManagerService.isCalculating;
        final isOffline = cacheManagerService.isOfflineMode;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF181818),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.download_for_offline_outlined,
                          color: Color(0xFF1DB954), size: 26),
                      SizedBox(width: 10),
                      Text(
                        'Downloads & Storage',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: isCalculating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1DB954),
                            ),
                          )
                        : const Icon(Icons.refresh, color: Colors.white70, size: 22),
                    onPressed: isCalculating
                        ? null
                        : () => cacheManagerService.refreshCacheSize(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Storage Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF202020),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2E2E2E)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Cached Data',
                          style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
                        ),
                        Text(
                          cache.formattedTotal,
                          style: const TextStyle(
                            color: Color(0xFF1DB954),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF2E2E2E), height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Web Cache & Streams',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          cache.formattedTemp,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'App Shell & Metadata',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          cache.formattedSupport,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Offline Mode Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF202020),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Color(0xFF1DB954), size: 24),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline Cache Mode',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Only serve cached content without network queries',
                            style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isOffline,
                      activeTrackColor: const Color(0xFF1DB954),
                      onChanged: (val) async {
                        await cacheManagerService.setOfflineMode(val);
                        onOfflineModeChanged?.call();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Clear Cache Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmClearCache(context),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text(
                    'Clear Cache',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF282828),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: Color(0xFF3E3E3E)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Storage Cache?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will delete cached audio streams and temporary page data to free space. Your login sessions and settings will be preserved.',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final cleared = await cacheManagerService.clearMediaCache(
                webViewController: webViewController,
              );
              if (context.mounted && cleared) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache successfully cleared'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

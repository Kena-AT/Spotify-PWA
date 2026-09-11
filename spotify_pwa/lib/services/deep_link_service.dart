import 'package:flutter/foundation.dart';

class DeepLinkService {
  static const String spotifyWebBase = 'https://open.spotify.com';

  /// Sanitizes and converts deep link URI (spotify:track:xxx or https://open.spotify.com/xxx)
  /// into a web-loadable open.spotify.com URL.
  static Uri? parseDeepLink(Uri uri) {
    try {
      if (uri.scheme == 'spotify') {
        // e.g., spotify:track:6rqhFgToBYV0KfaftqA8j0 -> https://open.spotify.com/track/6rqhFgToBYV0KfaftqA8j0
        // e.g., spotify:album:1DFim6p6qC2Z7203hB8a1g -> https://open.spotify.com/album/1DFim6p6qC2Z7203hB8a1g
        final pathSegments = uri.path.split(':').where((s) => s.isNotEmpty).toList();
        if (pathSegments.isNotEmpty) {
          final webPath = pathSegments.join('/');
          return Uri.parse('$spotifyWebBase/$webPath');
        }
      } else if (uri.host.contains('spotify.com')) {
        return uri;
      }
    } catch (e) {
      debugPrint('DeepLinkService parse error: $e');
    }
    return null;
  }
}

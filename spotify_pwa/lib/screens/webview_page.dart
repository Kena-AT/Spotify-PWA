import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SpotifyWebViewPage extends StatefulWidget {
  const SpotifyWebViewPage({Key? key}) : super(key: key);

  @override
  State<SpotifyWebViewPage> createState() => _SpotifyWebViewPageState();
}

class _SpotifyWebViewPageState extends State<SpotifyWebViewPage> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController(
      onPermissionRequest: (WebViewPermissionRequest request) {
        request.grant();
      },
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _injectViewportScript();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebResourceError: ${error.description}');
            // We ignore sub-resource errors to prevent the error overlay from showing
            // when ads or tracking scripts are blocked.
          },
        ),
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36')
      ..loadRequest(
        Uri.parse('https://open.spotify.com'),
      );
  }

  Future<void> _injectViewportScript() async {
    await _webViewController.runJavaScript('''
      (function() {
        let meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.name = 'viewport';
          document.head.appendChild(meta);
        }
        meta.setAttribute('content', 
          'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover');
      
        window.dispatchEvent(new Event('pwa-ready'));
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191414), // Spotify dark background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1DB954),
                ),
              ),
            if (_errorMessage != null)
              _buildErrorWidget(),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Color(0xFF1DB954),
          ),
          const SizedBox(height: 16),
          Text(
            'Connection Error',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Unable to load Spotify',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _initializeWebView();
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: const Color(0xFF191414),
            ),
          ),
        ],
      ),
    );
  }
}

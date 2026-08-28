import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/connectivity_service.dart';

class SpotifyWebViewPage extends StatefulWidget {
  const SpotifyWebViewPage({Key? key}) : super(key: key);

  @override
  State<SpotifyWebViewPage> createState() => _SpotifyWebViewPageState();
}

class _SpotifyWebViewPageState extends State<SpotifyWebViewPage> with WidgetsBindingObserver {
  late final WebViewController _webViewController;
  late final ConnectivityService _connectivityService;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _connectivityService = ConnectivityService();
    _connectivityService.addListener(_onConnectivityChanged);
    
    _initializeWebView();
  }

  void _onConnectivityChanged() {
    if (!_connectivityService.isOnline) {
      setState(() {
        _errorMessage = 'No internet connection';
      });
    } else if (_errorMessage == 'No internet connection') {
      // Auto-recover when internet comes back if that was the only error
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });
      _webViewController.reload();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivityService.removeListener(_onConnectivityChanged);
    _connectivityService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        print('App resumed');
        break;
      case AppLifecycleState.paused:
        print('App paused');
        break;
      case AppLifecycleState.detached:
        print('App detached');
        break;
      default:
        break;
    }
  }

  void _initializeWebView() {
    _webViewController = WebViewController(
      onPermissionRequest: (WebViewPermissionRequest request) {
        request.grant();
      },
    )
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFF1DB954),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connection Error',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF1DB954),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Unable to load Spotify. Please check your internet connection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFB3B3B3),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Column(
            children: [
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _connectivityService.checkConnection();
                    if (_connectivityService.isOnline) {
                      setState(() {
                        _errorMessage = null;
                        _isLoading = true;
                      });
                      _webViewController.reload();
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: const Color(0xFF191414),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _webViewController.goBack();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1DB954),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

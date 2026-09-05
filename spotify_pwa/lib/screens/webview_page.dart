import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../services/connectivity_service.dart';
import '../services/audio_service.dart';

class SpotifyWebViewPage extends StatefulWidget {
  const SpotifyWebViewPage({super.key});

  @override
  State<SpotifyWebViewPage> createState() => _SpotifyWebViewPageState();
}

class _SpotifyWebViewPageState extends State<SpotifyWebViewPage>
    with WidgetsBindingObserver {
  late final WebViewController _webViewController;
  late final ConnectivityService _connectivityService;
  bool _isLoading = true;
  String? _errorMessage;

  // Task 1.5 fix: a timer that dismisses a stuck loading indicator after 15s.
  Timer? _loadingTimeout;

  // Task 2.7: track the last known connectivity type to detect WiFi → cellular.
  ConnectivityResult _lastConnectivity = ConnectivityResult.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _connectivityService = ConnectivityService();
    _connectivityService.addListener(_onConnectivityChanged);

    _initializeWebView();
    _initLastConnectivity();
    _setupAudioService();
  }

  void _setupAudioService() async {
    await AudioService.startBackgroundAudio();
    
    // Setup handler for native playback control commands
    await AudioService.handlePlaybackControl(
      _handlePlaybackControl,
      _webViewController,
    );
  }

  void _handlePlaybackControl(String action) {
    debugPrint('[WebView] Received playback control: $action');
    
    // Send command to webview JavaScript
    _webViewController.runJavaScript('''
      if (window.playbackBridge) {
        window.playbackBridge.executeControl('$action');
      }
    ''');
  }

  Future<void> _initLastConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isNotEmpty) {
      _lastConnectivity = results.first;
    }
  }

  void _startLoadingTimeout() {
    _loadingTimeout?.cancel();
    // Task 1.5 fix: if the page hasn't finished loading in 15 seconds, dismiss
    // the spinner so the user isn't stuck looking at a rotating indicator.
    _loadingTimeout = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
        debugPrint('Loading timed out — spinner dismissed.');
      }
    });
  }

  void _onConnectivityChanged() {
    if (!_connectivityService.isOnline) {
      setState(() {
        _errorMessage = 'No internet connection';
      });
    } else if (_errorMessage == 'No internet connection') {
      // Auto-recover when internet comes back if that was the only error.
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });
      _startLoadingTimeout();
      _webViewController.reload();
    }
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
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
        // Task 2.7 — Network switching: re-check connectivity on resume.
        // This handles the case where the user switches networks (WiFi → cellular)
        // while the app was backgrounded.
        _handleResumeConnectivityCheck();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Cancel pending loading timeout when app goes to background.
        _loadingTimeout?.cancel();
        break;
      default:
        break;
    }
  }

  Future<void> _handleResumeConnectivityCheck() async {
    final results = await Connectivity().checkConnectivity();
    final newConnectivity =
        results.isNotEmpty ? results.first : ConnectivityResult.none;

    // Task 2.7 — Network switching: if the network type changed, reload to
    // ensure the session is still valid (e.g., WiFi → cellular handoff).
    if (newConnectivity != ConnectivityResult.none &&
        _lastConnectivity != ConnectivityResult.none &&
        newConnectivity != _lastConnectivity) {
      debugPrint(
          'Network changed from $_lastConnectivity to $newConnectivity — reloading.');
      setState(() => _isLoading = true);
      _startLoadingTimeout();
      _webViewController.reload();
    }
    _lastConnectivity = newConnectivity;

    // Also run the standard connectivity check.
    _connectivityService.checkConnection();
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
            _startLoadingTimeout();
          },
          onPageFinished: (String url) {
            _loadingTimeout?.cancel();
            setState(() => _isLoading = false);
            _injectViewportScript();
            _injectPlaybackBridgeScript();
          },
          onWebResourceError: (WebResourceError error) {
            // Only surface main-frame navigation errors to the user.
            // Sub-resource errors (ads, trackers) are ignored to prevent
            // false error overlays.
            if (error.isForMainFrame == true) {
              _loadingTimeout?.cancel();
              setState(() {
                _isLoading = false;
                _errorMessage =
                    'Unable to load Spotify. Please check your connection.';
              });
            } else {
              debugPrint(
                  'Sub-resource error (ignored): ${error.description}');
            }
          },
        ),
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'NativeChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            if (data['type'] == 'playback_state') {
              AudioService.updatePlaybackState(
                title: data['title'] ?? 'Unknown',
                artist: data['artist'] ?? 'Unknown',
                isPlaying: data['isPlaying'] ?? false,
                albumArtUrl: data['albumArtUrl'],
              );
            }
          } catch (e) {
            debugPrint('Error parsing playback state: $e');
          }
        },
      )
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36');

    // Task 2.7 — App restart with cached session: WebView uses the platform's
    // default cache mode (LOAD_DEFAULT on Android / NSURLRequestUseProtocolCachePolicy
    // on iOS), which reads cached responses and cookies from disk. Spotify session
    // cookies are therefore preserved across app restarts without any extra code.
    _webViewController.loadRequest(Uri.parse('https://open.spotify.com'));
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

  Future<void> _injectPlaybackBridgeScript() async {
    await _webViewController.runJavaScript(r'''
class PlaybackBridge {
  constructor() {
    this.lastState = null;
    this.interval = null;
    this.initialized = false;
  }
  init() {
    if (this.initialized) return;
    this.startObserver();
    window.addEventListener('playback-control', this.onNativeControl.bind(this));
    this.initialized = true;
  }
  startObserver() {
    if (this.interval) clearInterval(this.interval);
    this.interval = setInterval(() => this.detectPlaybackState(), 1000);
    this.detectPlaybackState();
  }
  detectPlaybackState() {
    try {
      const state = this.extractPlaybackState();
      if (!state) return;
      if (JSON.stringify(state) !== JSON.stringify(this.lastState)) {
        this.lastState = state;
        this.sendToNative(state);
      }
    } catch (error) {}
  }
  extractPlaybackState() {
    let title = 'Unknown';
    let artist = 'Unknown';
    let albumArtUrl = null;
    let isPlaying = false;

    // Method 1: MediaSession API (Highly robust for mobile and desktop)
    if (navigator.mediaSession && navigator.mediaSession.metadata) {
      const meta = navigator.mediaSession.metadata;
      if (meta.title) title = meta.title;
      if (meta.artist) artist = meta.artist;
      if (meta.artwork && meta.artwork.length > 0) {
        albumArtUrl = meta.artwork[meta.artwork.length - 1].src;
      }
      isPlaying = navigator.mediaSession.playbackState === 'playing';
      return { title, artist, isPlaying, albumArtUrl, timestamp: Date.now() };
    }

    // Method 2: DOM fallback
    const nowPlaying = document.querySelector('[data-testid="now-playing-widget"], #now-playing-bar, [data-testid="bottom-bar"]');
    if (nowPlaying) {
      const titleElement = nowPlaying.querySelector('[data-testid="track-title"], .track-name, [aria-label="Now playing:"]');
      const artistElement = nowPlaying.querySelector('[data-testid="track-artist"], .artist-name');
      if (titleElement) title = titleElement.textContent.trim();
      if (artistElement) artist = artistElement.textContent.trim();
      const imgElement = nowPlaying.querySelector('img');
      if (imgElement && imgElement.src) albumArtUrl = imgElement.src;
      
      const pauseButton = document.querySelector('[data-testid="control-button-pause"], [data-testid="pause-button"], button[aria-label="Pause"], .spoticon-pause-16');
      isPlaying = !!(pauseButton && !pauseButton.hidden);
      
      return { title, artist, isPlaying, albumArtUrl, timestamp: Date.now() };
    }

    return null;
  }
  sendToNative(state) {
    if (!window.NativeChannel) return;
    try {
      window.NativeChannel.postMessage(JSON.stringify({ type: 'playback_state', ...state }));
    } catch (error) {}
  }
  onNativeControl(event) {
    const action = event.detail?.action;
    if (action) this.executeControl(action);
  }
  executeControl(action) {
    switch (action) {
      case 'play': this.clickButton(['[data-testid="control-button-play"]', '[data-testid="play-button"]', 'button[aria-label="Play"]', '.spoticon-play-16']); break;
      case 'pause': this.clickButton(['[data-testid="control-button-pause"]', '[data-testid="pause-button"]', 'button[aria-label="Pause"]', '.spoticon-pause-16']); break;
      case 'next': this.clickButton(['[data-testid="control-button-skip-forward"]', '[data-testid="next-button"]', 'button[aria-label="Next"]', '.spoticon-skip-forward-16']); break;
      case 'previous': this.clickButton(['[data-testid="control-button-skip-back"]', '[data-testid="previous-button"]', 'button[aria-label="Previous"]', '.spoticon-skip-back-16']); break;
    }
  }
  clickButton(selectors) {
    try {
      for (const selector of selectors) {
        const button = document.querySelector(selector);
        if (button && !button.hidden && !button.disabled) {
          button.click();
          break;
        }
      }
    } catch (error) {}
  }
}
if (!window.playbackBridge) {
  window.playbackBridge = new PlaybackBridge();
  window.playbackBridge.init();
}
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191414),
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
              if (_errorMessage != null) _buildErrorWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: const Color(0xFF191414),
      child: Center(
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
                _errorMessage ??
                    'Unable to load Spotify. Please check your internet connection.',
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
                        _startLoadingTimeout();
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
      ),
    );
  }
}

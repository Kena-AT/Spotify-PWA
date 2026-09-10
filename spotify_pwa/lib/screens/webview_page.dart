import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // Only register handler for native playback control commands.
    // AudioService is started lazily when audio playback is detected.
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
    AudioService.stopBackgroundAudio();
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
            _injectAdBlockerScript();
          },
          onPageFinished: (String url) {
            _loadingTimeout?.cancel();
            setState(() => _isLoading = false);
            _injectViewportScript();
            _injectAdBlockerScript();
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
              final isPlaying = data['isPlaying'] == true;
              final title = (data['title'] as String?)?.trim();
              final artist = (data['artist'] as String?)?.trim();

              final hasValidTitle = title != null &&
                  title.isNotEmpty &&
                  title != 'Spotify' &&
                  title != 'Unknown' &&
                  !title.toLowerCase().contains('advertisement');

              if (hasValidTitle) {
                AudioService.updatePlaybackState(
                  title: title,
                  artist: (artist != null && artist != 'Unknown') ? artist : '',
                  isPlaying: isPlaying,
                  albumArtUrl: data['albumArtUrl'],
                  position: data['position'] != null ? (data['position'] as num).toInt() : null,
                  duration: data['duration'] != null ? (data['duration'] as num).toInt() : null,
                );
              } else if (!isPlaying) {
                // If nothing is playing and no valid track, ensure notification/service is dismissed
                AudioService.stopBackgroundAudio();
              }
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
        }
        meta.setAttribute('content', 
          'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover');
      
        window.dispatchEvent(new Event('pwa-ready'));
      })();
    ''');
  }

  Future<void> _injectAdBlockerScript() async {
    await _webViewController.runJavaScript(r'''
      (function() {
        if (window.__spotifyAdBlockerInstalled) return;
        window.__spotifyAdBlockerInstalled = true;

        // 1. Cosmetic CSS Injection: Hide all visual ad slots, banners & upgrade popups
        function injectAdBlockCSS() {
          if (document.getElementById('spotify-adblock-styles')) return;
          const style = document.createElement('style');
          style.id = 'spotify-adblock-styles';
          style.textContent = `
            [data-testid="ad-placeholder"],
            [data-testid="action-bar-ad"],
            [data-testid="ad-display-name"],
            [data-testid="ad-feedback-menu"],
            .main-leaderboardComponent-container,
            .main-topBar-upgradeButton,
            [aria-label="Upgrade to Premium"],
            a[href*="/upgrade"],
            button[data-testid="upgrade-button"],
            .upgrade-button,
            [data-testid="billboard-ad"],
            [data-testid="inactivity-dialog"],
            .sponsor-container,
            #ad-iframe,
            div[data-testid*="ad-"] {
              display: none !important;
              visibility: hidden !important;
              height: 0 !important;
              max-height: 0 !important;
              pointer-events: none !important;
              opacity: 0 !important;
            }
          `;
          (document.head || document.documentElement).appendChild(style);
        }
        injectAdBlockCSS();
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', injectAdBlockCSS);
        }

        // 2. API / Network Interception: Intercept ad-fetching endpoints
        const isAdUrl = (url) => {
          if (typeof url !== 'string') return false;
          return (
            url.includes('/ad-logic/') ||
            url.includes('/ads/v') ||
            url.includes('/v1/ads') ||
            url.includes('/ad-feedback/') ||
            url.includes('audio-ak-spotify-com.akamaized.net/ad') ||
            url.includes('doubleclick.net')
          );
        };

        if (window.fetch) {
          const origFetch = window.fetch;
          window.fetch = async function(...args) {
            const url = args[0] ? (typeof args[0] === 'string' ? args[0] : args[0].url || '') : '';
            if (isAdUrl(url)) {
              return new Response(JSON.stringify({
                ads: [],
                ad: null,
                tokens: [],
                client_timestamp: Date.now()
              }), {
                status: 200,
                headers: { 'Content-Type': 'application/json' }
              });
            }
            return origFetch.apply(this, args);
          };
        }

        if (window.XMLHttpRequest) {
          const origOpen = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url, ...rest) {
            this._url = url;
            return origOpen.apply(this, [method, url, ...rest]);
          };

          const origSend = XMLHttpRequest.prototype.send;
          XMLHttpRequest.prototype.send = function(...args) {
            if (this._url && isAdUrl(this._url.toString())) {
              Object.defineProperty(this, 'status', { value: 200, writable: false });
              Object.defineProperty(this, 'readyState', { value: 4, writable: false });
              Object.defineProperty(this, 'responseText', {
                value: JSON.stringify({ ads: [], ad: null }),
                writable: false
              });
              this.dispatchEvent(new Event('readystatechange'));
              this.dispatchEvent(new Event('load'));
              return;
            }
            return origSend.apply(this, args);
          };
        }

        // 3. Audio Ad Detector, Fast-Forwarder & Auto-Muter
        let isAdMuted = false;

        function checkAndSkipAds() {
          try {
            const title = (document.title || '').toLowerCase();
            const metaTitle = (navigator.mediaSession && navigator.mediaSession.metadata && navigator.mediaSession.metadata.title)
              ? navigator.mediaSession.metadata.title.toLowerCase()
              : '';

            const hasAdTitle = title.includes('advertisement') || metaTitle.includes('advertisement');
            const hasAdElement = 
              document.querySelector('[data-testid="ad-display-name"]') !== null ||
              document.querySelector('[aria-label*="Advertisement"]') !== null ||
              document.querySelector('[data-testid="track-info-advertiser"]') !== null;

            const isAd = hasAdTitle || hasAdElement;
            const mediaEls = document.querySelectorAll('audio, video');

            if (isAd) {
              isAdMuted = true;
              for (const el of mediaEls) {
                // Instantly silence audio ad
                el.muted = true;
                el.volume = 0;
                // Accelerate ad playback speed to max allowed (16x)
                el.playbackRate = 16.0;
                // Fast-forward to end if duration is available
                if (el.duration && !isNaN(el.duration) && isFinite(el.duration)) {
                  el.currentTime = el.duration;
                }
              }

              // Trigger skip to next song
              const skipBtn = document.querySelector(
                '[data-testid="control-button-skip-forward"], button[aria-label="Next"], button[aria-label="Skip forward"], [data-testid="next-button"]'
              );
              if (skipBtn) {
                skipBtn.click();
              } else if (window._spotifyHandlers && typeof window._spotifyHandlers['nexttrack'] === 'function') {
                try { window._spotifyHandlers['nexttrack']({ action: 'nexttrack' }); } catch (e) {}
              }
            } else if (isAdMuted) {
              // Regular song has resumed — restore volume and playback speed
              isAdMuted = false;
              for (const el of mediaEls) {
                el.muted = false;
                el.playbackRate = 1.0;
                el.volume = 1.0;
              }
            }
          } catch (e) {}
        }

        // Check every 150ms for instant reaction to ad events
        setInterval(checkAndSkipAds, 150);
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

    this.hookMediaSession();
    this.startObserver();
    window.addEventListener('playback-control', this.onNativeControl.bind(this));

    this.initialized = true;
  }

  hookMediaSession() {
    if (!navigator.mediaSession) return;

    window._spotifyHandlers = window._spotifyHandlers || {};
    const origSetActionHandler = navigator.mediaSession.setActionHandler.bind(navigator.mediaSession);

    navigator.mediaSession.setActionHandler = function(action, handler) {
      window._spotifyHandlers[action] = handler;
      return origSetActionHandler(action, handler);
    };
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

      if (!this.lastState ||
          this.lastState.title !== state.title ||
          this.lastState.artist !== state.artist ||
          this.lastState.isPlaying !== state.isPlaying ||
          this.lastState.albumArtUrl !== state.albumArtUrl) {
        this.lastState = state;
        this.sendToNative(state);
      }
    } catch (e) {}
  }

  extractPlaybackState() {
    let title = '';
    let artist = '';
    let albumArtUrl = null;
    let isPlaying = false;
    let position = 0;
    let duration = 0;

    // Strategy 1: Read MediaSession metadata directly (Set by Spotify)
    if (navigator.mediaSession && navigator.mediaSession.metadata) {
      const meta = navigator.mediaSession.metadata;
      if (meta.title && meta.title.trim().length > 0) {
        title = meta.title.trim();
      }
      if (meta.artist && meta.artist.trim().length > 0) {
        artist = meta.artist.trim();
      }
      if (meta.artwork && meta.artwork.length > 0) {
        albumArtUrl = meta.artwork[meta.artwork.length - 1].src;
      }
      if (navigator.mediaSession.playbackState === 'playing') {
        isPlaying = true;
      }
    }

    // Strategy 2: Parse document.title
    // When Spotify plays a song, document.title is always "Track • Artist" or "Track • Artist | Spotify"
    if (!title && document.title && document.title.includes('•')) {
      const cleaned = document.title.replace(/\s*\|\s*Spotify/i, '');
      const parts = cleaned.split('•');
      if (parts.length >= 2) {
        title = parts[0].trim();
        artist = parts.slice(1).join('•').trim();
      }
    }

    // Strategy 3: Check Spotify DOM now-playing elements (Desktop & Mobile)
    if (!title) {
      const trackLinks = document.querySelectorAll('a[href*="/track/"], [data-testid="nowplaying-track-link"], [data-testid="context-item-info-title"], [data-testid="track-info-name"]');
      for (const el of trackLinks) {
        const text = el.textContent ? el.textContent.trim() : '';
        if (text && text.length > 0 && !text.includes('Spotify')) {
          title = text;
          break;
        }
      }
    }

    if (!artist) {
      const artistLinks = document.querySelectorAll('a[href*="/artist/"], [data-testid="context-item-info-artist"], [data-testid="context-item-info-subtitles"], [data-testid="track-info-artists"]');
      for (const el of artistLinks) {
        const text = el.textContent ? el.textContent.trim() : '';
        if (text && text.length > 0) {
          artist = text;
          break;
        }
      }
    }

    if (!albumArtUrl) {
      const img = document.querySelector('footer img[src*="scdn.co"], [data-testid="now-playing-widget"] img, [data-testid="cover-art-image"], img[src*="image/ab67616d"]');
      if (img && img.src) {
        albumArtUrl = img.src;
      }
    }

    // Determine playing state
    // A) Check pause button in DOM (Pause button being visible means media is PLAYING)
    const pauseButton = document.querySelector(
      '[data-testid="control-button-playpause"][aria-label*="Pause"], [data-testid="control-button-pause"], [data-testid="pause-button"], button[aria-label="Pause"], .spoticon-pause-16'
    );
    if (pauseButton && !pauseButton.hidden && pauseButton.offsetParent !== null) {
      isPlaying = true;
    }

    // B) Check audio/video elements
    const mediaEls = document.querySelectorAll('audio, video');
    for (const el of mediaEls) {
      if (!el.paused && el.currentTime > 0) {
        isPlaying = true;
      }
      if (el.duration && !isNaN(el.duration)) {
        duration = Math.floor(el.duration * 1000);
        position = Math.floor(el.currentTime * 1000);
      }
    }

    // If no real title was found or an ad is active, don't publish an ad notification
    if (!title || title === 'Spotify' || title === 'Unknown' || title.toLowerCase().includes('advertisement')) {
      return null;
    }

    return {
      title: title,
      artist: artist,
      isPlaying: isPlaying,
      albumArtUrl: albumArtUrl,
      position: position,
      duration: duration
    };
  }

  sendToNative(state) {
    if (!window.NativeChannel) return;
    try {
      window.NativeChannel.postMessage(JSON.stringify({ type: 'playback_state', ...state }));
    } catch (e) {}
  }

  onNativeControl(event) {
    const action = event.detail?.action;
    if (action) this.executeControl(action);
  }

  executeControl(action) {
    console.log('[PlaybackBridge] Executing control:', action);

    // 1. Try Spotify's registered MediaSession handlers
    const handlers = window._spotifyHandlers || {};
    if (action === 'play' && typeof handlers['play'] === 'function') {
      try { handlers['play']({ action: 'play' }); return; } catch (e) {}
    }
    if (action === 'pause' && typeof handlers['pause'] === 'function') {
      try { handlers['pause']({ action: 'pause' }); return; } catch (e) {}
    }
    if (action === 'next' && typeof handlers['nexttrack'] === 'function') {
      try { handlers['nexttrack']({ action: 'nexttrack' }); return; } catch (e) {}
    }
    if (action === 'previous' && typeof handlers['previoustrack'] === 'function') {
      try { handlers['previoustrack']({ action: 'previoustrack' }); return; } catch (e) {}
    }

    // 2. Fallback: DOM Buttons
    switch (action) {
      case 'play':
        this.clickButton([
          '[data-testid="control-button-playpause"][aria-label*="Play"]',
          '[data-testid="control-button-play"]',
          '[data-testid="play-button"]',
          'button[aria-label="Play"]',
          '[data-testid="control-button-playpause"]'
        ]);
        break;
      case 'pause':
        this.clickButton([
          '[data-testid="control-button-playpause"][aria-label*="Pause"]',
          '[data-testid="control-button-pause"]',
          '[data-testid="pause-button"]',
          'button[aria-label="Pause"]',
          '[data-testid="control-button-playpause"]'
        ]);
        break;
      case 'next':
        this.clickButton([
          '[data-testid="control-button-skip-forward"]',
          'button[aria-label="Next"]',
          'button[aria-label="Skip forward"]',
          '[data-testid="next-button"]'
        ]);
        break;
      case 'previous':
        this.clickButton([
          '[data-testid="control-button-skip-back"]',
          'button[aria-label="Previous"]',
          'button[aria-label="Skip back"]',
          '[data-testid="previous-button"]'
        ]);
        break;
    }

    // 3. Fallback: Media elements
    if (action === 'pause') {
      document.querySelectorAll('audio, video').forEach(el => el.pause());
    } else if (action === 'play') {
      document.querySelectorAll('audio, video').forEach(el => el.play().catch(() => {}));
    }
  }

  clickButton(selectors) {
    for (const sel of selectors) {
      const btn = document.querySelector(sel);
      if (btn && !btn.hidden && !btn.disabled) {
        btn.click();
        return;
      }
    }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (await _webViewController.canGoBack()) {
          await _webViewController.goBack();
        } else {
          // If no previous page in web history, minimize/exit app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
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

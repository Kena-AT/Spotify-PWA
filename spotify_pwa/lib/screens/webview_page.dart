import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../services/connectivity_service.dart';
import '../services/audio_service.dart';
import '../services/analytics_service.dart';
import '../services/deep_link_service.dart';
import '../services/platform_service.dart';

class SpotifyWebViewPage extends StatefulWidget {
  const SpotifyWebViewPage({super.key});

  @override
  State<SpotifyWebViewPage> createState() => _SpotifyWebViewPageState();
}

class _SpotifyWebViewPageState extends State<SpotifyWebViewPage>
    with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  late final ConnectivityService _connectivityService;
  bool _isLoading = true;
  String? _errorMessage;

  Timer? _loadingTimeout;
  ConnectivityResult _lastConnectivity = ConnectivityResult.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _connectivityService = ConnectivityService();
    _connectivityService.addListener(_onConnectivityChanged);

    _initLastConnectivity();
    _setupAudioService();
    _checkPlatformVersion();
  }

  Future<void> _checkPlatformVersion() async {
    final version = await PlatformService.getPlatformVersion();
    debugPrint('[WebViewPage] Running on native platform: $version');
  }

  Future<void> loadDeepLink(Uri deepLinkUri) async {
    final parsed = DeepLinkService.parseDeepLink(deepLinkUri);
    if (parsed != null && _webViewController != null) {
      debugPrint('[WebViewPage] Navigating to deep link: $parsed');
      await _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri.uri(parsed)));
    }
  }

  void _setupAudioService() async {
    await AudioService.handlePlaybackControl(
      _handlePlaybackControl,
      _webViewController,
    );
  }

  void _handlePlaybackControl(String action) {
    debugPrint('[WebView] Received playback control: $action');
    _webViewController?.evaluateJavascript(source: '''
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
    _loadingTimeout = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
        debugPrint('Loading timed out — spinner dismissed.');
      }
    });
  }

  void _onConnectivityChanged() {
    AnalyticsService.logConnectivityChanged(_connectivityService.isOnline);
    if (!_connectivityService.isOnline) {
      setState(() {
        _errorMessage = 'No internet connection';
      });
    } else if (_errorMessage == 'No internet connection') {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });
      _startLoadingTimeout();
      _webViewController?.reload();
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
        _handleResumeConnectivityCheck();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
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

    if (newConnectivity != ConnectivityResult.none &&
        _lastConnectivity != ConnectivityResult.none &&
        newConnectivity != _lastConnectivity) {
      debugPrint(
          'Network changed from $_lastConnectivity to $newConnectivity — reloading.');
      setState(() => _isLoading = true);
      _startLoadingTimeout();
      _webViewController?.reload();
    }
    _lastConnectivity = newConnectivity;
    _connectivityService.checkConnection();
  }

  // --- Multi-Layer AdBlocker Engine Rules ---

  List<ContentBlocker> _buildAdBlockContentBlockers() {
    return [
      // Rule 1: Block Spotify ad-logic and ad-fetching API endpoints
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: r'.*spclient\.wg\.spotify\.com/(ad-logic|ads|ad-feedback|ad-event)/.*',
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
      // Rule 2: Block audio ad stream CDN endpoints
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: r'.*audio-.*spotify.*\.com/ad/.*',
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: r'.*audio-ak-spotify-com\.akamaized\.net/ad/.*',
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
      // Rule 3: Block third-party ad networks and trackers
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: r'.*(doubleclick\.net|googlesyndication\.com|google-analytics\.com|adservice\.google|scorecardresearch\.com).*',
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
      // Rule 4: Hide visual ad placeholders and upgrade buttons
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: '.*'),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.CSS_DISPLAY_NONE,
          selector: '[data-testid="ad-placeholder"], [data-testid="action-bar-ad"], [data-testid="ad-display-name"], [data-testid="ad-feedback-menu"], .main-leaderboardComponent-container, .main-topBar-upgradeButton, [aria-label="Upgrade to Premium"], a[href*="/upgrade"], button[data-testid="upgrade-button"], .upgrade-button, [data-testid="billboard-ad"], [data-testid="inactivity-dialog"], .sponsor-container, #ad-iframe, div[data-testid*="ad-"]',
        ),
      ),
    ];
  }

  // --- Document-Start Script (Injects before page JS runs) ---
  static const String _adBlockerStartScript = r'''
  (function() {
    if (window.__spotifyAdBlockerEngine) return;
    window.__spotifyAdBlockerEngine = true;

    // 1. Cosmetic CSS Injection
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

    // 2. Network API Interception at Document Start
    const isAdUrl = function(url) {
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
            status: "NO_ADS",
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
            value: JSON.stringify({ ads: [], ad: null, status: "NO_ADS" }),
            writable: false
          });
          this.dispatchEvent(new Event('readystatechange'));
          this.dispatchEvent(new Event('load'));
          return;
        }
        return origSend.apply(this, args);
      };
    }

    // 3. Universal Media Elements Tracker (Captures both in-DOM and in-memory new Audio() elements)
    const trackedMedia = new Set();

    function registerMedia(el) {
      if (!el || trackedMedia.has(el)) return;
      trackedMedia.add(el);
      el.addEventListener('play', sweepAds, true);
      el.addEventListener('playing', sweepAds, true);
      el.addEventListener('timeupdate', sweepAds, true);
    }

    // Intercept new Audio()
    const RealAudio = window.Audio;
    window.Audio = function(...args) {
      const audio = new RealAudio(...args);
      registerMedia(audio);
      return audio;
    };
    window.Audio.prototype = RealAudio.prototype;

    // Intercept document.createElement('audio' / 'video')
    const realCreateElement = document.createElement;
    document.createElement = function(tag, ...rest) {
      const el = realCreateElement.call(document, tag, ...rest);
      if (tag && typeof tag === 'string') {
        const lower = tag.toLowerCase();
        if (lower === 'audio' || lower === 'video') {
          registerMedia(el);
        }
      }
      return el;
    };

    // Intercept HTMLMediaElement.prototype.play
    const realPlay = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function() {
      registerMedia(this);
      sweepAds();
      return realPlay.apply(this, arguments);
    };

    // 4. Ultra-Aggressive Audio Ad Detector, Auto-Muter & Fast-Forwarder Watchdog
    let isMutedByAd = false;
    let savedVolume = 1.0;

    function isAdActive() {
      // Check 1: Document title and MediaSession metadata — only match explicit ad keywords
      const title = (document.title || '').toLowerCase();
      const meta = (navigator.mediaSession && navigator.mediaSession.metadata) ? navigator.mediaSession.metadata : null;
      const metaTitle = (meta && meta.title) ? meta.title.toLowerCase() : '';
      const metaArtist = (meta && meta.artist) ? meta.artist.toLowerCase() : '';

      if (title.includes('advertisement') || title.includes('spotify ad') ||
          metaTitle.includes('advertisement') || metaTitle.includes('spotify ad') ||
          metaArtist === 'advertisement' || metaArtist === 'spotify ad') {
        return true;
      }

      // Check 2: Explicit DOM ad indicators
      if (
        document.querySelector('[data-testid="ad-display-name"]') !== null ||
        document.querySelector('[data-testid="track-info-advertiser"]') !== null ||
        document.querySelector('[data-testid="ad-feedback-menu"]') !== null ||
        document.querySelector('[aria-label*="Advertisement" i]') !== null ||
        document.querySelector('[aria-label*="sponsored" i]') !== null ||
        document.querySelector('.ad-placeholder') !== null ||
        document.querySelector('#ad-iframe') !== null ||
        document.querySelector('[data-testid="billboard-ad"]') !== null
      ) {
        return true;
      }

      return false;
    }

    function sweepAds() {
      try {
        // Collect any elements in DOM as well
        document.querySelectorAll('audio, video').forEach(registerMedia);

        const ad = isAdActive();

        for (const el of trackedMedia) {
          const src = (el.src || el.currentSrc || '').toLowerCase();
          const isAdSource = src.includes('/ad/') || src.includes('doubleclick') || src.includes('googleads');

          if (ad || isAdSource) {
            if (!isMutedByAd) {
              savedVolume = (el.volume > 0) ? el.volume : 1.0;
            }
            // 1. Instantly silence ad
            el.muted = true;
            el.volume = 0;
            // 2. Accelerate ad to max speed
            el.playbackRate = 16.0;
            // 3. Fast-forward to end of ad stream and dispatch ended event
            if (el.duration && !isNaN(el.duration) && isFinite(el.duration) && el.duration > 0) {
              el.currentTime = el.duration;
              el.dispatchEvent(new Event('ended'));
            }
          }
        }

        if (ad) {
          isMutedByAd = true;
          // 4. Trigger next-track buttons immediately
          const skipBtn = document.querySelector(
            '[data-testid="control-button-skip-forward"], button[aria-label="Next"], button[aria-label="Skip forward"], [data-testid="next-button"]'
          );
          if (skipBtn && !skipBtn.disabled && skipBtn.getAttribute('aria-disabled') !== 'true') {
            skipBtn.click();
          } else if (window._spotifyHandlers && typeof window._spotifyHandlers['nexttrack'] === 'function') {
            try { window._spotifyHandlers['nexttrack']({ action: 'nexttrack' }); } catch (e) {}
          }
        } else if (isMutedByAd) {
          // Real track has resumed — restore volume
          isMutedByAd = false;
          for (const el of trackedMedia) {
            el.muted = false;
            el.volume = savedVolume > 0 ? savedVolume : 1.0;
            el.playbackRate = 1.0;
          }
        }
      } catch (e) {}
    }

    // High frequency loop (every 50ms) for instant ad muting
    setInterval(sweepAds, 50);

    // Event hooks for zero-latency detection on media state changes
    document.addEventListener('play', sweepAds, true);
    document.addEventListener('timeupdate', sweepAds, true);
    document.addEventListener('loadedmetadata', sweepAds, true);
  })();
  ''';

  // --- Playback Bridge Script ---
  static const String _playbackBridgeScript = r'''
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

      // Strategy 1: Check document.title first. On Spotify Web, document.title is always "Track • Artist"
      if (document.title && document.title.includes('•')) {
        const cleaned = document.title.replace(/\s*\|\s*Spotify/i, '');
        const parts = cleaned.split('•');
        if (parts.length >= 2) {
          title = parts[0].trim();
          artist = parts.slice(1).join('•').trim();
        }
      }

      // Strategy 2: MediaSession metadata (set by Spotify)
      if (navigator.mediaSession && navigator.mediaSession.metadata) {
        const meta = navigator.mediaSession.metadata;
        if (!title && meta.title && meta.title.trim().length > 0 && !meta.title.toLowerCase().includes('advertisement')) {
          title = meta.title.trim();
        }
        if (!artist && meta.artist && meta.artist.trim().length > 0 && meta.artist.toLowerCase() !== 'unknown') {
          artist = meta.artist.trim();
        }
        if (meta.artwork && meta.artwork.length > 0) {
          albumArtUrl = meta.artwork[meta.artwork.length - 1].src;
        }
        if (navigator.mediaSession.playbackState === 'playing') {
          isPlaying = true;
        }
      }

      // Strategy 3: ONLY query within the now-playing bar container, NEVER across the document!
      const playerBar = document.querySelector('[data-testid="now-playing-widget"], footer, [data-testid="context-item-info-title"]');
      if (playerBar) {
        if (!title) {
          const tLink = playerBar.querySelector('a[href*="/track/"], [data-testid="nowplaying-track-link"], [data-testid="context-item-info-title"]');
          if (tLink && tLink.textContent && !tLink.textContent.includes('Spotify')) {
            title = tLink.textContent.trim();
          }
        }
        if (!artist) {
          const aLink = playerBar.querySelector('a[href*="/artist/"], [data-testid="context-item-info-artist"], [data-testid="context-item-info-subtitles"]');
          if (aLink && aLink.textContent) {
            artist = aLink.textContent.trim();
          }
        }
      }

      if (!albumArtUrl) {
        const img = document.querySelector('footer img[src*="scdn.co"], [data-testid="now-playing-widget"] img, [data-testid="cover-art-image"], img[src*="image/ab67616d"]');
        if (img && img.src) {
          albumArtUrl = img.src;
        }
      }

      const pauseButton = document.querySelector(
        '[data-testid="control-button-playpause"][aria-label*="Pause"], [data-testid="control-button-pause"], [data-testid="pause-button"], button[aria-label="Pause"], .spoticon-pause-16'
      );
      if (pauseButton && !pauseButton.hidden && pauseButton.offsetParent !== null) {
        isPlaying = true;
      }

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
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('NativeChannel', JSON.stringify({ type: 'playback_state', ...state }));
      }
    }

    onNativeControl(event) {
      const action = event.detail?.action;
      if (action) this.executeControl(action);
    }

    executeControl(action) {
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
  ''';

  void _handlePlaybackStateMessage(String rawMessage) {
    try {
      final data = jsonDecode(rawMessage);
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
          AnalyticsService.logPlaybackStateChanged(title: title, isPlaying: isPlaying);
          AudioService.updatePlaybackState(
            title: title,
            artist: (artist != null && artist != 'Unknown') ? artist : '',
            isPlaying: isPlaying,
            albumArtUrl: data['albumArtUrl'],
            position: data['position'] != null ? (data['position'] as num).toInt() : null,
            duration: data['duration'] != null ? (data['duration'] as num).toInt() : null,
          );
        } else if (!isPlaying) {
          AudioService.stopBackgroundAudio();
        }
      }
    } catch (e) {
      debugPrint('Error parsing playback state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (_webViewController != null && await _webViewController!.canGoBack()) {
          await _webViewController!.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri('https://open.spotify.com')),
                  initialSettings: InAppWebViewSettings(
                    useShouldInterceptRequest: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    cacheMode: CacheMode.LOAD_DEFAULT,
                    userAgent:
                        'Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
                    contentBlockers: _buildAdBlockContentBlockers(),
                  ),
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                      source: _adBlockerStartScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                    UserScript(
                      source: _playbackBridgeScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  ]),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;

                    // Add JavaScript handler for native bridge
                    controller.addJavaScriptHandler(
                      handlerName: 'NativeChannel',
                      callback: (args) {
                        if (args.isNotEmpty && args[0] is String) {
                          _handlePlaybackStateMessage(args[0] as String);
                        }
                      },
                    );
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _startLoadingTimeout();
                  },
                  onLoadStop: (controller, url) async {
                    _loadingTimeout?.cancel();
                    setState(() => _isLoading = false);
                  },
                  onReceivedError: (controller, request, error) {
                    if (request.isForMainFrame == true) {
                      _loadingTimeout?.cancel();
                      setState(() {
                        _isLoading = false;
                        _errorMessage =
                            'Unable to load Spotify. Please check your connection.';
                      });
                    } else {
                      debugPrint('Sub-resource error (ignored): ${error.description}');
                    }
                  },
                  shouldInterceptRequest: (controller, request) async {
                    final url = request.url.toString();
                    // Intercept ad endpoints and return empty mocked JSON/media response
                    if (url.contains('/ad-logic/') ||
                        url.contains('/ads/v') ||
                        url.contains('/ad-feedback/') ||
                        url.contains('/ad-event/') ||
                        url.contains('/commercial/') ||
                        (url.contains('audio-sp-') && url.contains('/ad/')) ||
                        url.contains('audio-ak-spotify-com.akamaized.net/ad') ||
                        url.contains('doubleclick.net') ||
                        url.contains('googlesyndication.com') ||
                        url.contains('google-analytics.com') ||
                        url.contains('adservice.google') ||
                        url.contains('scorecardresearch.com')) {
                      return WebResourceResponse(
                        contentType: 'application/json',
                        contentEncoding: 'utf-8',
                        data: Uint8List.fromList('{"ads":[],"status":"NO_ADS"}'.codeUnits),
                        statusCode: 200,
                        reasonPhrase: 'OK',
                      );
                    }
                    return null;
                  },
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                ),
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
      color: Theme.of(context).scaffoldBackgroundColor,
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
                        _webViewController?.reload();
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
                    _webViewController?.goBack();
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

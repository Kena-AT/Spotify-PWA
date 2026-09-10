/**
 * Playback Bridge
 * Detects changes in Spotify web player and communicates with native layer
 */

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

  stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
    this.initialized = false;
  }
}

let playbackBridge = null;
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    playbackBridge = new PlaybackBridge();
    playbackBridge.init();
  });
} else {
  playbackBridge = new PlaybackBridge();
  playbackBridge.init();
}

window.PlaybackBridge = playbackBridge;

// --- Ad Blocker Engine for Web ---
(function initAdBlocker() {
  if (window.__spotifyAdBlockerInstalled) return;
  window.__spotifyAdBlockerInstalled = true;

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

  // 2. Network / API Interception
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
          el.muted = true;
          el.volume = 0;
          el.playbackRate = 16.0;
          if (el.duration && !isNaN(el.duration) && isFinite(el.duration)) {
            el.currentTime = el.duration;
          }
        }

        const skipBtn = document.querySelector(
          '[data-testid="control-button-skip-forward"], button[aria-label="Next"], button[aria-label="Skip forward"], [data-testid="next-button"]'
        );
        if (skipBtn) {
          skipBtn.click();
        } else if (window._spotifyHandlers && typeof window._spotifyHandlers['nexttrack'] === 'function') {
          try { window._spotifyHandlers['nexttrack']({ action: 'nexttrack' }); } catch (e) {}
        }
      } else if (isAdMuted) {
        isAdMuted = false;
        for (const el of mediaEls) {
          el.muted = false;
          el.playbackRate = 1.0;
          el.volume = 1.0;
        }
      }
    } catch (e) {}
  }

  setInterval(checkAndSkipAds, 150);
})();


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

  /**
   * Initialize the playback bridge
   * Should be called when DOM is ready and Spotify is loaded
   */
  init() {
    if (this.initialized) return;
    
    console.log('[PlaybackBridge] Initializing...');
    
    // Start monitoring playback state
    this.startObserver();
    
    // Listen for messages from native
    window.addEventListener('playback-control', this.onNativeControl.bind(this));
    
    this.initialized = true;
    console.log('[PlaybackBridge] Initialized');
  }

  /**
   * Start interval observer to detect playback changes
   */
  startObserver() {
    // Clear existing interval if any
    if (this.interval) {
      clearInterval(this.interval);
    }
    
    // Check playback state every 1 second
    this.interval = setInterval(() => {
      this.detectPlaybackState();
    }, 1000);
    
    // Initial check
    this.detectPlaybackState();
  }

  /**
   * Detect current playback state from Spotify DOM
   */
  detectPlaybackState() {
    try {
      const state = this.extractPlaybackState();
      
      if (!state) {
        // Spotify not yet loaded or not playing
        return;
      }

      // Only send if state changed
      if (JSON.stringify(state) !== JSON.stringify(this.lastState)) {
        this.lastState = state;
        this.sendToNative(state);
      }
    } catch (error) {
      console.error('[PlaybackBridge] Error detecting playback state:', error);
    }
  }

  /**
   * Extract playback state from Spotify DOM
   * Returns: { title, artist, isPlaying, albumArtUrl }
   */
  extractPlaybackState() {
    // Method 1: Try now-playing widget (most reliable)
    const nowPlaying = document.querySelector('[data-testid="now-playing-widget"]');
    if (!nowPlaying) {
      return null; // Spotify not playing or not fully loaded
    }

    const titleElement = nowPlaying.querySelector('[data-testid="track-title"]');
    const artistElement = nowPlaying.querySelector('[data-testid="track-artist"]');
    
    if (!titleElement || !artistElement) {
      return null;
    }

    // Get title and artist text
    const title = titleElement.textContent?.trim() || 'Unknown';
    const artist = artistElement.textContent?.trim() || 'Unknown';

    // Get album art URL
    let albumArtUrl = null;
    const imgElement = nowPlaying.querySelector('img');
    if (imgElement && imgElement.src) {
      albumArtUrl = imgElement.src;
    }

    // Determine if playing by checking for the pause button
    // The pause button being visible means music is currently playing
    const pauseButton = document.querySelector('[data-testid="control-button-pause"], button[aria-label="Pause"]');
    const isPlaying = pauseButton && !pauseButton.hidden ? true : false;

    return {
      title,
      artist,
      isPlaying,
      albumArtUrl,
      timestamp: Date.now(),
    };
  }

  /**
   * Send playback state to native layer via NativeChannel
   */
  sendToNative(state) {
    if (!window.NativeChannel) {
      console.warn('[PlaybackBridge] NativeChannel not available');
      return;
    }

    const message = {
      type: 'playback_state',
      ...state,
    };

    try {
      window.NativeChannel.postMessage(JSON.stringify(message));
      console.log('[PlaybackBridge] Sent state:', message);
    } catch (error) {
      console.error('[PlaybackBridge] Error sending to native:', error);
    }
  }

  /**
   * Handle playback control commands from native layer
   */
  onNativeControl(event) {
    const action = event.detail?.action;
    if (!action) return;

    console.log('[PlaybackBridge] Received native control:', action);
    this.executeControl(action);
  }

  /**
   * Execute a playback control action
   */
  executeControl(action) {
    switch (action) {
      case 'play':
        this.clickButton(['[data-testid="control-button-play"]', 'button[aria-label="Play"]', '.spoticon-play-16']);
        break;
      case 'pause':
        this.clickButton(['[data-testid="control-button-pause"]', 'button[aria-label="Pause"]', '.spoticon-pause-16']);
        break;
      case 'next':
        this.clickButton(['[data-testid="control-button-skip-forward"]', 'button[aria-label="Next"]', '.spoticon-skip-forward-16']);
        break;
      case 'previous':
        this.clickButton(['[data-testid="control-button-skip-back"]', 'button[aria-label="Previous"]', '.spoticon-skip-back-16']);
        break;
      default:
        console.warn('[PlaybackBridge] Unknown action:', action);
    }
  }

  /**
   * Click a Spotify control button using an array of possible selectors
   */
  clickButton(selectors) {
    try {
      let button = null;
      for (const selector of selectors) {
        button = document.querySelector(selector);
        if (button && !button.hidden && !button.disabled) {
          break; // Found a valid button
        }
      }

      if (!button) {
        console.warn('[PlaybackBridge] Button not found for selectors:', selectors);
        return;
      }

      button.click();
      console.log('[PlaybackBridge] Clicked button:', button);
    } catch (error) {
      console.error('[PlaybackBridge] Error clicking button:', error);
    }
  }

  /**
   * Stop the observer (cleanup)
   */
  stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
    this.initialized = false;
    console.log('[PlaybackBridge] Stopped');
  }

  /**
   * Debug: Get current state
   */
  getCurrentState() {
    return this.lastState;
  }

  /**
   * Debug: Force state check
   */
  forceCheck() {
    this.detectPlaybackState();
  }
}

// Global instance
let playbackBridge = null;

// Initialize when document ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    playbackBridge = new PlaybackBridge();
    playbackBridge.init();
  });
} else {
  // Already loaded
  playbackBridge = new PlaybackBridge();
  playbackBridge.init();
}

// Expose for debugging
window.PlaybackBridge = playbackBridge;

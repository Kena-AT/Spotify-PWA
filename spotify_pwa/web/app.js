// Viewport management
function setupViewport() {
  // Check if running in webview
  const isWebView = () => {
    return /WebView|webview|wv|flutterWebView/i.test(navigator.userAgent);
  };

  if (isWebView()) {
    document.body.classList.add('webview-context');
  }

  // Set CSS variable for viewport height (handles address bar)
  function updateViewportHeight() {
    const vh = window.innerHeight * 0.01;
    document.documentElement.style.setProperty('--vh', `${vh}px`);
  }

  // Update on load, resize, and orientation change
  window.addEventListener('load', updateViewportHeight);
  window.addEventListener('resize', updateViewportHeight);
  window.addEventListener('orientationchange', updateViewportHeight);
  
  // Initial call
  updateViewportHeight();

  // Prevent zoom on input focus (optional, can be removed if problematic)
  document.addEventListener('touchstart', (e) => {
    if (e.target.matches('input, textarea, select')) {
      // Allow interaction but prevent zoom
      document.body.style.zoom = 1;
    }
  });
}

// Initialize on DOM ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', setupViewport);
} else {
  setupViewport();
}

// Listen for PWA ready event from Flutter
window.addEventListener('pwa-ready', () => {
  console.log('PWA initialized in Flutter webview');
});

// Graceful error handling
window.addEventListener('error', (event) => {
  console.error('App error:', event.message);
});

window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled promise rejection:', event.reason);
});

// Export for debugging
window.appDebug = {
  isWebView: () => /WebView|webview|wv|flutterWebView/i.test(navigator.userAgent),
  viewportHeight: () => window.innerHeight,
  viewportWidth: () => window.innerWidth,
  devicePixelRatio: () => window.devicePixelRatio,
  userAgent: () => navigator.userAgent,
};

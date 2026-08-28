// Viewport management
function setupViewport() {
  const isWebView = /WebView|webview|wv|flutterWebView/i.test(navigator.userAgent);
  if (isWebView) document.body.classList.add('webview-context');

  const updateVH = () => {
    document.documentElement.style.setProperty('--vh', `${window.innerHeight * 0.01}px`);
  };

  const events = ['load', 'resize', 'orientationchange'];
  events.forEach(e => window.addEventListener(e, updateVH));
  updateVH();
}

document.readyState === 'loading' 
  ? document.addEventListener('DOMContentLoaded', setupViewport)
  : setupViewport();

// Listen for PWA ready event from Flutter
window.addEventListener('pwa-ready', () => {
  console.log('PWA initialized in Flutter webview');
});

// Register Service Worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker.js')
      .then((registration) => {
        console.log('ServiceWorker registration successful with scope: ', registration.scope);
      })
      .catch((err) => {
        console.log('ServiceWorker registration failed: ', err);
      });
  });
}

// Graceful error handling
window.addEventListener('error', (event) => {
  console.error('App error:', event.message);
});

window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled promise rejection:', event.reason);
});

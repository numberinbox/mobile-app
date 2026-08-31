const androidStore = 'https://play.google.com/store/apps/details?id=com.numberinbox.app';
const iosStore = 'https://apps.apple.com/app/twake-mail/id1587086189';
const openAppDeepLink = 'twakemail.mobile://openapp';
const iosPlatform = 'iOS';
const androidPlatform = 'android';
const otherPlatform = 'other';

function getPlatform() {
  const ua = navigator.userAgent || navigator.vendor || window.opera;
  console.info('[NumberInbox] getPlatform():', ua);
  if (/iPhone|iPad|iPod/i.test(ua)) return iosPlatform;
  if (/Android/i.test(ua)) return androidPlatform;
  return otherPlatform;
}

function openNumberInboxApp() {
  const os = getPlatform();
  console.info('[NumberInbox] handleOpenNumberInboxApp() - OS:', os);

  let fallbackTimer;
  let hiddenAt = null;

  const clearFallback = (reason) => {
    if (fallbackTimer) clearTimeout(fallbackTimer);
    console.info(`[NumberInbox] Cancel store redirect: ${reason}`);
    window.removeEventListener('blur', onBlur);
    document.removeEventListener('visibilitychange', onVisibility);
    window.removeEventListener('pagehide', onPageHide);
  };

  const onVisibility = () => {
    if (document.hidden) {
      hiddenAt = Date.now();
      clearFallback('document hidden (user left browser)');
    }
  };

  const onBlur = () => {
    hiddenAt = Date.now();
    clearFallback('window blurred (likely app opened)');
  };

  const onPageHide = () => clearFallback('page hidden');

  document.addEventListener('visibilitychange', onVisibility);
  window.addEventListener('blur', onBlur);
  window.addEventListener('pagehide', onPageHide);

  const tryOpen = (deeplink, storeUrl) => {
    const start = Date.now();
    window.location.href = deeplink;

    // fallback only if still visible after 1500 ms AND page wasn’t hidden recently
    fallbackTimer = setTimeout(() => {
      if (!document.hidden && (!hiddenAt || Date.now() - hiddenAt > 800)) {
        console.info('[NumberInbox] Deep link failed — redirecting to store.');
        window.location.href = storeUrl;
      } else {
        console.info('[NumberInbox] App likely opened — skip store redirect.');
      }
    }, 1500);
  };

  if (os === androidPlatform) {
    tryOpen(openAppDeepLink, androidStore);
  } else if (os === iosPlatform) {
    tryOpen(openAppDeepLink, iosStore);
  } else {
    console.info('[NumberInbox] Unsupported platform. No app open.');
  }

  closeSmartBanner();
}

function initialTmailApp() {
  const os = getPlatform();
  const originInUrl = window.location;

  console.info('[NumberInbox] initialTmailApp(): OriginInUrl:', originInUrl);

  // Skip displaying the banner on desktop browsers
  if (os === otherPlatform || typeof window === 'undefined') {
    console.info('[NumberInbox] Skipping smart-banner on desktop.');
    return;
  }

  // By default, show the banner on mobile
  showSmartBanner();

  // Ensure the banner stays on top after Flutter re-renders
  const observer = new MutationObserver(() => {
    const banner = document.querySelector('.smart-banner');
    if (banner) banner.style.zIndex = '9999999';
  });
  observer.observe(document.body, { childList: true, subtree: true });
}

function showSmartBanner() {
  console.info('[NumberInbox] showSmartBanner(): Displaying the smart banner.');
  const smartBanner = document.querySelector('.smart-banner');
  if (!smartBanner) return;

  smartBanner.style.display = "block";
  smartBanner.style.zIndex = '9999999';
  smartBanner.style.top = "16px";
  document.body.style.overflow = "hidden";
}

function closeSmartBanner() {
  console.info('[NumberInbox] closeSmartBanner(): Closing the smart banner.');
  const smartBanner = document.querySelector('.smart-banner');
  if (!smartBanner) return;

  smartBanner.style.display = "none";
  smartBanner.style.top = 0;
  document.body.style.overflow = "auto";
}
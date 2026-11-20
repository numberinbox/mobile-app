const closeSmartBannerButton = document.querySelector('.smart-banner button.close');
if (closeSmartBannerButton) closeSmartBannerButton.addEventListener('click', closeSmartBanner);
const openNumberInboxAppButton = document.getElementById('open-button-id');
if (openNumberInboxAppButton) openNumberInboxAppButton.addEventListener('click', openNumberInboxApp);

    {{flutter_js}}
    {{flutter_build_config}}

    // currentScript is null inside the async loader callback below.
    var cspNonce = document.currentScript && document.currentScript.nonce;

    initializeLocalizedApp(initialTmailApp);

    if ('serviceWorker' in navigator) {
      navigator
        .serviceWorker
        .getRegistrations()
        .then(async function(registrations) {
          try {
            await Promise.all(registrations.map(function(registration) {
              return registration.unregister();
            }));
          } catch (error) {
            console.log('[NumberInbox] Error unregistering service worker: ', error);
          }
          _flutter.loader.load({
            nonce: cspNonce,
            config: { nonce: cspNonce },
            onEntrypointLoaded: async function(engineInitializer) {
              const appRunner = await engineInitializer.initializeEngine({
                fontFallbackBaseUrl: '',
                nonce: cspNonce
              });
              await appRunner.runApp();
            }
          });
        });
    } else {
      _flutter.loader.load({
        nonce: cspNonce,
        config: { nonce: cspNonce },
        onEntrypointLoaded: async function(engineInitializer) {
          const appRunner = await engineInitializer.initializeEngine({
            fontFallbackBaseUrl: '',
            nonce: cspNonce
          });
          await appRunner.runApp();
        }
      });
    }

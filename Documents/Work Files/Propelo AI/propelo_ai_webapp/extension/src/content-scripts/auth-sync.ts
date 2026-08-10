/**
 * Auth Sync Content Script - RECONSTRUCTED
 * Runs on https://app.propeloai.com to sync Firebase auth tokens to extension
 */

(function () {


  // Mark that extension is installed (for webapp detection)
  const marker = document.createElement('div');
  marker.id = 'propelo-extension-installed';
  marker.setAttribute('data-version', '1.0.0');
  marker.style.display = 'none';
  document.documentElement.appendChild(marker);


  // Also dispatch a custom event for more reliable detection
  window.dispatchEvent(new CustomEvent('propelo-extension-ready', { detail: { version: '1.0.0' } }));

  let lastToken: string | null = null;
  let checkCount = 0;

  function checkAndSyncAuth() {
    try {
      checkCount++;


      // Get ALL localStorage keys
      const allKeys = Object.keys(localStorage);


      // Find Firebase auth keys
      const firebaseAuthKeys = allKeys.filter(k => k.startsWith('firebase:authUser:'));

      if (firebaseAuthKeys.length > 0) {


        const authKey = firebaseAuthKeys[0];
        const authDataStr = localStorage.getItem(authKey);

        if (authDataStr) {


          try {
            const authData = JSON.parse(authDataStr);
            const email = authData.email || 'unknown';
            const userId = authData.uid || authData.localId;
            const token = authData.stsTokenManager?.accessToken;
            const displayName = authData.displayName || '';
            const photoURL = authData.photoURL || '';





            if (token && token !== lastToken) {


              // Create complete userData object for extension
              const userData = {
                uid: userId,
                email: email,
                firstName: displayName.split(' ')[0] || '',
                lastName: displayName.split(' ').slice(1).join(' ') || '',
                profileImage: photoURL,
                plan: 'free'
              };

              // Save EVERYTHING the extension needs
              chrome.storage.local.set({
                authToken: token,
                userId: userId,
                userEmail: email,
                userData: userData,  // <-- Complete user data object
                lastAuthSync: Date.now()
              }, () => {
                if (chrome.runtime.lastError) {
                  console.error('[Propelo Auth Sync] ❌ Chrome storage error:', chrome.runtime.lastError);
                } else {





                  lastToken = token;

                  // Verify it was saved
                  chrome.storage.local.get(['authToken', 'userId', 'userEmail', 'userData'], (result) => {
                    // Verification successful
                  });

                  // Notify background
                  chrome.runtime.sendMessage({
                    action: 'AUTH_STATE_CHANGED',
                    payload: { authenticated: true, email, userId }
                  }).catch(() => {

                  });
                }
              });
            } else if (token) {

            } else {

            }
          } catch (parseError) {
            console.error('[Propelo Auth Sync] ❌ Parse error:', parseError);
          }
        } else {

        }
      } else {




        // Check for other auth indicators
        const hasSessionCookie = document.cookie.includes('session=');
        if (hasSessionCookie) {

        }
      }

    } catch (error) {
      console.error('[Propelo Auth Sync] ❌ Error:', error);
    }
  }

  // Initial check after 1 second (give page time to load)

  setTimeout(() => {

    checkAndSyncAuth();
  }, 1000);

  // Check every 2 seconds
  setInterval(checkAndSyncAuth, 2000);

  // Listen for localStorage changes
  window.addEventListener('storage', (e) => {
    if (e.key?.startsWith('firebase:authUser:')) {

      setTimeout(checkAndSyncAuth, 100);
    }
  });


})();

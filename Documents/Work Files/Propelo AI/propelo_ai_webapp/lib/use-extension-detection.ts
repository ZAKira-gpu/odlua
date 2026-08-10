"use client";

import { useState, useEffect } from "react";

interface ExtensionInfo {
  installed: boolean;
  version: string | null;
}

/**
 * Hook to detect if the Propelo Chrome extension is installed.
 * The extension injects a hidden DOM element with id 'propelo-extension-installed'
 * and dispatches a custom event 'propelo-extension-ready' when loaded.
 */
export function useExtensionDetection(): ExtensionInfo {
  const [extensionInfo, setExtensionInfo] = useState<ExtensionInfo>({
    installed: false,
    version: null,
  });

  useEffect(() => {
    // Check for DOM marker (immediate check)
    const checkDOMMarker = () => {
      const marker = document.getElementById("propelo-extension-installed");
      if (marker) {
        const version = marker.getAttribute("data-version");
        setExtensionInfo({ installed: true, version });
        return true;
      }
      return false;
    };

    // Check immediately
    if (checkDOMMarker()) {
      return;
    }

    // Listen for the custom event (extension might load after this component)
    const handleExtensionReady = (event: CustomEvent<{ version: string }>) => {
      setExtensionInfo({
        installed: true,
        version: event.detail?.version || null,
      });
    };

    window.addEventListener(
      "propelo-extension-ready",
      handleExtensionReady as EventListener
    );

    // Also check periodically for the first 5 seconds (in case extension loads slowly)
    const intervals: NodeJS.Timeout[] = [];
    for (let i = 1; i <= 5; i++) {
      intervals.push(
        setTimeout(() => {
          if (!extensionInfo.installed) {
            checkDOMMarker();
          }
        }, i * 1000)
      );
    }

    return () => {
      window.removeEventListener(
        "propelo-extension-ready",
        handleExtensionReady as EventListener
      );
      intervals.forEach(clearTimeout);
    };
  }, []);

  return extensionInfo;
}

/**
 * Simple sync check - useful for SSR or immediate detection
 */
export function isExtensionInstalled(): boolean {
  if (typeof window === "undefined") return false;
  return !!document.getElementById("propelo-extension-installed");
}

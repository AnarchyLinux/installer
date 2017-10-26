"use strict";

// Firefox 55 erroneously sends messages from the content script to the
// devtools panel:
// https://bugzilla.mozilla.org/show_bug.cgi?id=1383310
// As a workaround, listen for messages only if this isn't the devtools panel.
// Note that Firefox processes API access lazily, so chrome.devtools will always
// exist but will have undefined as its value on other pages.
if (!chrome.devtools)
{
  // Listen for messages from the background page.
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) =>
  {
    return ext.onMessage._dispatch(message, {}, sendResponse).includes(true);
  });
}

(function()
{
  let port = null;

  ext.onExtensionUnloaded = {
    addListener(listener)
    {
      if (!port)
        port = chrome.runtime.connect();

      // When the extension is reloaded, disabled or uninstalled the
      // background page dies and automatically disconnects all ports
      port.onDisconnect.addListener(listener);
    },
    removeListener(listener)
    {
      if (port)
      {
        port.onDisconnect.removeListener(listener);

        if (!port.onDisconnect.hasListeners())
        {
          port.disconnect();
          port = null;
        }
      }
    }
  };
}());

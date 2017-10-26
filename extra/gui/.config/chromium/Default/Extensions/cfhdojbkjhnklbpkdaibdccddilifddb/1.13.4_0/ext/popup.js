"use strict";

(function()
{
  if (typeof chrome == "undefined" || typeof chrome.extension == "undefined")
    window.chrome = browser;
  const backgroundPage = chrome.extension.getBackgroundPage();
  window.ext = Object.create(backgroundPage.ext);

  window.ext.closePopup = () =>
  {
    window.close();
  };

  // Calling i18n.getMessage from the background page causes Edge to throw an
  // exception.
  // https://developer.microsoft.com/en-us/microsoft-edge/platform/issues/12793975/
  window.ext.i18n = chrome.i18n;

  // We have to override ext.backgroundPage, because in order
  // to send messages the local "chrome" namespace must be used.
  window.ext.backgroundPage = {
    sendMessage: chrome.runtime.sendMessage,

    getWindow()
    {
      return backgroundPage;
    }
  };
}());

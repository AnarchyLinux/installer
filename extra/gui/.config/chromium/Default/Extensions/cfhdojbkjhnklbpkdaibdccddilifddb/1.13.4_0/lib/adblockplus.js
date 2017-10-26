if (typeof require != "function")
{
  var require = function(module)
  {
    if (!(module in require.scopes))
    {
      let scope = {exports: {}};
      require.scopes[module] = require.modules[module](scope, scope.exports);
    }
    return require.scopes[module];
  };
  require.modules = Object.create(null);
  require.scopes = Object.create(null);
}


require.modules["info"] = function(module, exports)
{

/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

"use strict";

let platformVersion = null;
let application = null;
let applicationVersion;

let regexp = /(\S+)\/(\S+)(?:\s*\(.*?\))?/g;
let match;

while (match = regexp.exec(navigator.userAgent))
{
  let app = match[1];
  let ver = match[2];

  if (app == "Chrome")
  {
    platformVersion = ver;
  }
  else if (app != "Mozilla" && app != "AppleWebKit" && app != "Safari")
  {
    // For compatibility with legacy websites, Chrome's UA
    // also includes a Mozilla, AppleWebKit and Safari token.
    // Any further name/version pair indicates a fork.
    application = app == "OPR" ? "opera" : app.toLowerCase();
    applicationVersion = ver;
  }
}

// not a Chromium-based UA, probably modifed by the user
if (!platformVersion)
{
  application = "unknown";
  applicationVersion = platformVersion = "0";
}

// no additional name/version, so this is upstream Chrome
if (!application)
{
  application = "chrome";
  applicationVersion = platformVersion;
}


exports.addonName = "adblockpluschrome";
exports.addonVersion = "1.13.4";

exports.application = application;
exports.applicationVersion = applicationVersion;

exports.platform = "chromium";
exports.platformVersion = platformVersion;

return module.exports;
};
require.modules["cssInjection"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module cssInjection */

"use strict";

const {RegExpFilter} = require("filterClasses");
const {ElemHide} = require("elemHide");
const {checkWhitelisted} = require("whitelisting");
const {extractHostFromFrame} = require("url");
const {port} = require("messaging");
const devtools = require("devtools");

let userStylesheetsSupported = true;

function hideElements(tabId, frameId, selectors)
{
  let code = selectors.join(", ") + "{display: none !important;}";

  try
  {
    chrome.tabs.insertCSS(tabId,
      {
        code,
        cssOrigin: "user",
        frameId,
        matchAboutBlank: true,
        runAt: "document_start"
      }
    );
    return true;
  }
  catch (error)
  {
    if (/\bError processing cssOrigin\b/.test(error.message) == -1)
      throw error;

    userStylesheetsSupported = false;
    return false;
  }
}

port.on("elemhide.getSelectors", (msg, sender) =>
{
  let selectors;
  let trace = devtools && devtools.hasPanel(sender.page);

  if (!checkWhitelisted(sender.page, sender.frame,
                        RegExpFilter.typeMap.DOCUMENT |
                        RegExpFilter.typeMap.ELEMHIDE))
  {
    let specificOnly = checkWhitelisted(sender.page, sender.frame,
                                        RegExpFilter.typeMap.GENERICHIDE);
    selectors = ElemHide.getSelectorsForDomain(
      extractHostFromFrame(sender.frame),
      specificOnly ? ElemHide.SPECIFIC_ONLY : ElemHide.ALL_MATCHING
    );
  }
  else
  {
    selectors = [];
  }

  if (selectors.length == 0 || userStylesheetsSupported &&
      hideElements(sender.page.id, sender.frame.id, selectors))
  {
    if (trace)
      return {selectors, trace: true, inject: false};

    return {trace: false, inject: false};
  }

  return {selectors, trace, inject: true};
});

port.on("elemhide.injectSelectors", (msg, sender) =>
{
  return hideElements(sender.page.id, sender.frame.id, msg.selectors);
});

return module.exports;
};

require.modules["filterComposer"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module filterComposer */

"use strict";

const {defaultMatcher} = require("matcher");
const {RegExpFilter} = require("filterClasses");
const {FilterNotifier} = require("filterNotifier");
const {Prefs} = require("prefs");
const {extractHostFromFrame, stringifyURL, isThirdParty} = require("url");
const {getKey, checkWhitelisted} = require("whitelisting");
const {port} = require("messaging");
const info = require("info");

let readyPages = new ext.PageMap();

/**
 * Checks whether the given page is ready to use the filter composer
 *
 * @param {Page} page
 * @return {boolean}
 */
exports.isPageReady = page =>
{
  return readyPages.has(page);
};

function isValidString(s)
{
  return s && s.indexOf("\0") == -1;
}

function escapeChar(chr)
{
  let code = chr.charCodeAt(0);

  // Control characters and leading digits must be escaped based on
  // their char code in CSS. Moreover, curly brackets aren't allowed
  // in elemhide filters, and therefore must be escaped based on their
  // char code as well.
  if (code <= 0x1F || code == 0x7F || /[\d{}]/.test(chr))
    return "\\" + code.toString(16) + " ";

  return "\\" + chr;
}

let escapeCSS =
/**
 * Escapes a token (e.g. tag, id, class or attribute) to be used in
 * CSS selectors.
 *
 * @param {string} s
 * @return {string}
 * @static
 */
exports.escapeCSS = s =>
{
  return s.replace(/^[\d-]|[^\w\-\u0080-\uFFFF]/g, escapeChar);
};

let quoteCSS =
/**
 * Quotes a string to be used as attribute value in CSS selectors.
 *
 * @param {string} value
 * @return {string}
 * @static
 */
exports.quoteCSS = value =>
{
  return '"' + value.replace(/["\\{}\x00-\x1F\x7F]/g, escapeChar) + '"';
};

function composeFilters(details)
{
  let {page, frame} = details;
  let filters = [];
  let selectors = [];

  if (!checkWhitelisted(page, frame))
  {
    let typeMask = RegExpFilter.typeMap[details.type];
    let docDomain = extractHostFromFrame(frame);
    let specificOnly = checkWhitelisted(page, frame,
                                        RegExpFilter.typeMap.GENERICBLOCK);

    // Add a blocking filter for each URL of the element that can be blocked
    for (let url of details.urls)
    {
      let urlObj = new URL(url, details.baseURL);
      url = stringifyURL(urlObj);

      let filter = defaultMatcher.whitelist.matchesAny(
        url, typeMask, docDomain,
        isThirdParty(urlObj, docDomain),
        getKey(page, frame), specificOnly
      );

      if (!filter)
      {
        let filterText = url.replace(/^[\w-]+:\/+(?:www\.)?/, "||");

        if (specificOnly)
          filterText += "$domain=" + docDomain;

        if (!filters.includes(filterText))
          filters.push(filterText);
      }
    }

    // If we couldn't generate any blocking filters, fallback to element hiding
    if (filters.length == 0 && !checkWhitelisted(page, frame,
                                                 RegExpFilter.typeMap.ELEMHIDE))
    {
      // Generate CSS selectors based on the element's "id" and
      // "class" attribute.
      if (isValidString(details.id))
        selectors.push("#" + escapeCSS(details.id));

      let classes = details.classes.filter(isValidString);
      if (classes.length > 0)
        selectors.push(classes.map(c => "." + escapeCSS(c)).join(""));

      // If there is a "src" attribute, specifiying a URL that we can't block,
      // generate a CSS selector matching the "src" attribute
      if (isValidString(details.src))
      {
        selectors.push(
          escapeCSS(details.tagName) + "[src=" + quoteCSS(details.src) + "]"
        );
      }

      // As last resort, if there is a "style" attribute, and we
      // couldn't generate any filters so far, generate a CSS selector
      // matching the "style" attribute
      if (isValidString(details.style) && selectors.length == 0 &&
          filters.length == 0)
      {
        selectors.push(
          escapeCSS(details.tagName) + "[style=" + quoteCSS(details.style) + "]"
        );
      }

      // Add an element hiding filter for each generated CSS selector
      for (let selector of selectors)
        filters.push(docDomain.replace(/^www\./, "") + "##" + selector);
    }
  }

  return {filters, selectors};
}

let contextMenuItem = {
  title: ext.i18n.getMessage("block_element"),
  contexts: ["image", "video", "audio"],
  onclick(page)
  {
    page.sendMessage({type: "composer.content.contextMenuClicked"});
  }
};

function updateContextMenu(page, filter)
{
  page.contextMenus.remove(contextMenuItem);

  if (typeof filter == "undefined")
    filter = checkWhitelisted(page);

  // We don't support the filter composer on Firefox for Android, because the
  // user experience on mobile is quite different.
  if (info.application != "fennec" &&
      !filter && Prefs.shouldShowBlockElementMenu && readyPages.has(page))
  {
    page.contextMenus.create(contextMenuItem);
  }
}

FilterNotifier.on("page.WhitelistingStateRevalidate", updateContextMenu);

Prefs.on("shouldShowBlockElementMenu", () =>
{
  ext.pages.query({}, pages =>
  {
    for (let page of pages)
      updateContextMenu(page);
  });
});

port.on("composer.ready", (message, sender) =>
{
  readyPages.set(sender.page, null);
  updateContextMenu(sender.page);
});

port.on("composer.openDialog", (message, sender) =>
{
  return new Promise(resolve =>
  {
    ext.windows.create({
      url: ext.getURL("composer.html"),
      left: 50,
      top: 50,
      width: 420,
      height: 200,
      type: "popup"
    },
    popupPage =>
    {
      let popupPageId = popupPage.id;
      function onRemoved(removedPageId)
      {
        if (popupPageId == removedPageId)
        {
          sender.page.sendMessage({
            type: "composer.content.dialogClosed",
            popupId: popupPageId
          });
          ext.pages.onRemoved.removeListener(onRemoved);
        }
      }
      ext.pages.onRemoved.addListener(onRemoved);
      resolve(popupPageId);
    });
  });
});

port.on("composer.getFilters", (message, sender) =>
{
  return composeFilters({
    tagName: message.tagName,
    id: message.id,
    src: message.src,
    style: message.style,
    classes: message.classes,
    urls: message.urls,
    type: message.mediatype,
    baseURL: message.baseURL,
    page: sender.page,
    frame: sender.frame
  });
});

port.on("composer.quoteCSS", (message, sender) =>
{
  return quoteCSS(message.CSS);
});

ext.pages.onLoading.addListener(page =>
{
  page.sendMessage({type: "composer.content.finished"});
});

return module.exports;
};

require.modules["filterValidation"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module filterValidation */

"use strict";

const {Filter, InvalidFilter, ElemHideBase, ElemHideEmulationFilter} =
      require("filterClasses");
const {Utils} = require("utils");

/**
 * An error returned by
 * {@link module:filterValidation.parseFilter parseFilter()} or
 * {@link module:filterValidation.parseFilters parseFilters()}
 * indicating that a given filter cannot be parsed,
 * contains an invalid CSS selector or is a filter list header.
 *
 * @param {string} type See documentation in the constructor below.
 * @param {Object} [details] Contains the "reason" and / or "selector"
 *                           properties.
 * @constructor
 */
function FilterParsingError(type, details)
{
  /**
   * Indicates why the filter is rejected. Possible choices:
   * "invalid-filter", "invalid-css-selector", "unexpected-filter-list-header"
   *
   * @type {string}
   */
  this.type = type;

  if (details)
  {
    if ("reason" in details)
      this.reason = details.reason;
    if ("selector" in details)
      this.selector = details.selector;
  }
}
FilterParsingError.prototype = {
  /**
   * The line number the error occurred on if
   * {@link module:filterValidation.parseFilters parseFilters()}
   * were used. Or null if the error was returned by
   * {@link module:filterValidation.parseFilter parseFilter()}.
   *
   * @type {?number}
   */
  lineno: null,

  /**
   * Returns a detailed translated error message.
   *
   * @return {string}
   */
  toString()
  {
    let message;
    if (this.reason)
      message = Utils.getString(this.reason);
    else
    {
      message = ext.i18n.getMessage(
        this.type.replace(/-/g, "_"),
        "selector" in this ? "'" + this.selector + "'" : null
      );
    }

    if (this.lineno)
    {
      message = ext.i18n.getMessage(
        "line", this.lineno.toLocaleString()
      ) + ": " + message;
    }
    return message;
  }
};

function isValidCSSSelector(selector)
{
  let style = document.createElement("style");
  document.documentElement.appendChild(style);
  let {sheet} = style;
  document.documentElement.removeChild(style);

  try
  {
    document.querySelector(selector);
    sheet.insertRule(selector + "{}", 0);
  }
  catch (e)
  {
    return false;
  }
  return true;
}

/**
 * @typedef ParsedFilter
 * @property {?Filter} [filter]
 *   The parsed filter if it is valid. Or null if the given string is empty.
 * @property {FilterParsingError} [error]
 *   See {@link module:filterValidation~FilterParsingError FilterParsingError}
 */

let parseFilter =
/**
 * Parses and validates a filter given by the user.
 *
 * @param {string}  text
 * @return {ParsedFilter}
 */
exports.parseFilter = text =>
{
  let filter = null;
  text = Filter.normalize(text);

  if (text)
  {
    if (text[0] == "[")
      return {error: new FilterParsingError("unexpected-filter-list-header")};

    filter = Filter.fromText(text);

    if (filter instanceof InvalidFilter)
    {
      return {error: new FilterParsingError("invalid-filter",
                                            {reason: filter.reason})};
    }
    if (filter instanceof ElemHideBase &&
        !(filter instanceof ElemHideEmulationFilter) &&
        !isValidCSSSelector(filter.selector))
    {
      return {error: new FilterParsingError("invalid-css-selector",
                                            {selector: filter.selector})};
    }
  }

  return {filter};
};

/**
 * @typedef ParsedFilters
 * @property {Filter[]} filters
 *   The parsed result without invalid filters.
 * @property {FilterParsingError[]} errors
 *   See {@link module:filterValidation~FilterParsingError FilterParsingError}
 */

/**
 * Parses and validates a newline-separated list of filters given by the user.
 *
 * @param {string}  text
 * @return {ParsedFilters}
 */
exports.parseFilters = text =>
{
  let lines = text.split("\n");
  let filters = [];
  let errors = [];

  for (let i = 0; i < lines.length; i++)
  {
    let {filter, error} = parseFilter(lines[i]);

    if (filter)
      filters.push(filter);

    if (error)
    {
      error.lineno = i + 1;
      errors.push(error);
    }
  }

  return {filters, errors};
};

return module.exports;
};

require.modules["icon"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module icon */

"use strict";

const {FilterNotifier} = require("filterNotifier");

const frameOpacities = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9,
                        1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
                        0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0];
const numberOfFrames = frameOpacities.length;

let stopRequested = false;
let canUpdateIcon = true;
let notRunning = Promise.resolve();
let whitelistedState = new ext.PageMap();

function loadImage(url)
{
  return new Promise((resolve, reject) =>
  {
    let image = new Image();
    image.src = url;
    image.addEventListener("load", () =>
    {
      resolve(image);
    });
    image.addEventListener("error", () =>
    {
      reject("Failed to load image " + url);
    });
  });
}

function setIcon(page, notificationType, opacity, frames)
{
  opacity = opacity || 0;
  let whitelisted = !!whitelistedState.get(page);

  if (!notificationType || !frames)
  {
    if (opacity > 0.5)
    {
      page.browserAction.setIcon("/icons/abp-$size-notification-" +
                                 notificationType + ".png");
    }
    else
    {
      page.browserAction.setIcon("/icons/abp-$size" +
                                 (whitelisted ? "-whitelisted" : "") + ".png");
    }
  }
  else
  {
    chrome.browserAction.setIcon({
      tabId: page.id,
      imageData: frames["" + opacity + whitelisted]
    });
  }
}

FilterNotifier.on("page.WhitelistingStateRevalidate", (page, filter) =>
{
  whitelistedState.set(page, !!filter);
  if (canUpdateIcon)
    setIcon(page);
});

function renderFrames(notificationType)
{
  return Promise.all([
    loadImage("icons/abp-16.png"),
    loadImage("icons/abp-16-whitelisted.png"),
    loadImage("icons/abp-16-notification-" + notificationType + ".png"),
    loadImage("icons/abp-19.png"),
    loadImage("icons/abp-19-whitelisted.png"),
    loadImage("icons/abp-19-notification-" + notificationType + ".png"),
    loadImage("icons/abp-20.png"),
    loadImage("icons/abp-20-whitelisted.png"),
    loadImage("icons/abp-20-notification-" + notificationType + ".png"),
    loadImage("icons/abp-32.png"),
    loadImage("icons/abp-32-whitelisted.png"),
    loadImage("icons/abp-32-notification-" + notificationType + ".png"),
    loadImage("icons/abp-38.png"),
    loadImage("icons/abp-38-whitelisted.png"),
    loadImage("icons/abp-38-notification-" + notificationType + ".png"),
    loadImage("icons/abp-40.png"),
    loadImage("icons/abp-40-whitelisted.png"),
    loadImage("icons/abp-40-notification-" + notificationType + ".png")
  ]).then(images =>
  {
    let imageMap = {
      16: {base: [images[0], images[1]], overlay: images[2]},
      19: {base: [images[3], images[4]], overlay: images[5]},
      20: {base: [images[6], images[7]], overlay: images[8]},
      32: {base: [images[9], images[10]], overlay: images[11]},
      38: {base: [images[12], images[13]], overlay: images[14]},
      40: {base: [images[15], images[16]], overlay: images[17]}
    };

    let frames = {};
    let canvas = document.createElement("canvas");
    let context = canvas.getContext("2d");

    for (let whitelisted of [false, true])
    {
      for (let i = 0, opacity = 0; i <= 10; opacity = ++i / 10)
      {
        let imageData = {};
        let sizes = [16, 19, 20, 32, 38, 40];
        for (let size of sizes)
        {
          canvas.width = size;
          canvas.height = size;
          context.globalAlpha = 1;
          context.drawImage(imageMap[size]["base"][whitelisted | 0], 0, 0);
          context.globalAlpha = opacity;
          context.drawImage(imageMap[size]["overlay"], 0, 0);
          imageData[size] = context.getImageData(0, 0, size, size);
        }
        frames["" + opacity + whitelisted] = imageData;
      }
    }

    return frames;
  });
}

function animateIcon(notificationType, frames)
{
  ext.pages.query({active: true}, pages =>
  {
    let animationStep = 0;
    let opacity = 0;

    let onActivated = page =>
    {
      pages.push(page);
      setIcon(page, notificationType, opacity, frames);
    };
    ext.pages.onActivated.addListener(onActivated);

    canUpdateIcon = false;
    let interval = setInterval(() =>
    {
      let oldOpacity = opacity;
      opacity = frameOpacities[animationStep++];

      if (opacity != oldOpacity)
      {
        for (let page of pages)
        {
          if (whitelistedState.has(page))
            setIcon(page, notificationType, opacity, frames);
        }
      }

      if (animationStep > numberOfFrames)
      {
        clearInterval(interval);
        ext.pages.onActivated.removeListener(onActivated);
        canUpdateIcon = true;
      }
    }, 100);
  });
}

let stopIconAnimation =
/**
 * Stops to animate the browser action icon
 * after the current interval has been finished.
 *
 * @return {Promise} A promise that is fullfilled when
 *                   the icon animation has been stopped.
 */
exports.stopIconAnimation = () =>
{
  stopRequested = true;
  return notRunning.then(() =>
  {
    stopRequested = false;
  });
};

/**
 * Starts to animate the browser action icon to indicate a pending notifcation.
 * If the icon is already animated, it replaces the previous
 * animation as soon as the current interval has been finished.
 *
 * @param {string} type  The notification type (i.e: "information" or
 *                       "critical".)
 */
exports.startIconAnimation = type =>
{
  notRunning = new Promise(resolve =>
  {
    Promise.all([renderFrames(type), stopIconAnimation()]).then(results =>
    {
      if (stopRequested)
      {
        resolve();
        return;
      }

      let frames = results[0];
      animateIcon(type, frames);

      let interval = setInterval(() =>
      {
        if (stopRequested)
        {
          clearInterval(interval);
          resolve();
          return;
        }

        animateIcon(type, frames);
      }, 10000);
    });
  });
};

return module.exports;
};

require.modules["io"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

const keyPrefix = "file:";

function fileToKey(fileName)
{
  return keyPrefix + fileName;
}

function loadFile(fileName)
{
  return new Promise((resolve, reject) =>
  {
    let key = fileToKey(fileName);

    ext.storage.get(key, items =>
    {
      let entry = items[key];

      if (entry)
        resolve(entry);
      else
        reject({type: "NoSuchFile"});
    });
  });
}

function saveFile(fileName, data)
{
  return new Promise((resolve, reject) =>
  {
    ext.storage.set(
      fileToKey(fileName),
      {
        content: Array.from(data),
        lastModified: Date.now()
      },
      resolve
    );
  });
}

function removeFile(fileName)
{
  return new Promise((resolve, reject) =>
  {
    ext.storage.remove(fileToKey(fileName), () =>
    {
      if (chrome.runtime.lastError)
        reject(chrome.runtime.lastError.message);
      else
        resolve();
    });
  });
}

exports.IO =
{
  /**
   * Reads text lines from a file.
   * @param {string} fileName
   *    Name of the file to be read
   * @param {TextSink} listener
   *    Function that will be called for each line in the file
   * @return {Promise}
   *    Promise to be resolved or rejected once the operation is completed
   */
  readFromFile(fileName, listener)
  {
    return loadFile(fileName).then(entry =>
    {
      for (let line of entry.content)
        listener(line);
    });
  },

  /**
   * Writes text lines to a file.
   * @param {string} fileName
   *    Name of the file to be written
   * @param {Iterable.<string>} data
   *    An array-like or iterable object containing the lines (without line
   *    endings)
   * @return {Promise}
   *    Promise to be resolved or rejected once the operation is completed
   */
  writeToFile(fileName, data)
  {
    return saveFile(fileName, data);
  },

  /**
   * Copies a file.
   * @param {string} fromFile
   *    Name of the file to be copied
   * @param {string} toFile
   *    Name of the file to be written, will be overwritten if exists
   * @return {Promise}
   *    Promise to be resolved or rejected once the operation is completed
   */
  copyFile(fromFile, toFile)
  {
    return loadFile(fromFile).then(entry => saveFile(toFile, entry.content));
  },

  /**
   * Renames a file.
   * @param {string} fromFile
   *    Name of the file to be renamed
   * @param {string} newName
   *    New file name, will be overwritten if exists
   * @return {Promise}
   *    Promise to be resolved or rejected once the operation is completed
   */
  renameFile(fromFile, newName)
  {
    return loadFile(fromFile).then(entry =>
    {
      return new Promise((resolve, reject) =>
      {
        ext.storage.set(fileToKey(newName), entry, () =>
        {
          if (chrome.runtime.lastError)
            reject(chrome.runtime.lastError.message);
          else
            resolve();
        });
      });
    }).then(() => removeFile(fromFile));
  },

  /**
   * Removes a file.
   * @param {string} fileName
   *    Name of the file to be removed
   * @return {Promise}
   *    Promise to be resolved or rejected once the operation is completed
   */
  removeFile(fileName)
  {
    return removeFile(fileName);
  },

  /**
   * Retrieves file metadata.
   * @param {string} fileName
   *    Name of the file to be looked up
   * @return {Promise.<StatData>}
   *    Promise to be resolved with file metadata once the operation is
   *    completed
   */
  statFile(fileName)
  {
    return loadFile(fileName).then(entry =>
    {
      return {
        exists: true,
        lastModified: entry.lastModified
      };
    }).catch(error =>
    {
      if (error.type == "NoSuchFile")
        return {exists: false};
      throw error;
    });
  }
};

return module.exports;
};

require.modules["messaging"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module messaging */

"use strict";

const {EventEmitter} = require("events");

/**
 * Communication port wrapping ext.onMessage to receive messages.
 *
 * @constructor
 */
function Port()
{
  this._eventEmitter = new EventEmitter();
  this._onMessage = this._onMessage.bind(this);
  ext.onMessage.addListener(this._onMessage);
}

Port.prototype = {
  _onMessage(message, sender, sendResponse)
  {
    let async = false;
    let callbacks = this._eventEmitter.listeners(message.type);

    for (let callback of callbacks)
    {
      let response = callback(message, sender);

      if (response && typeof response.then == "function")
      {
        response.then(
          sendResponse,
          reason =>
          {
            console.error(reason);
            sendResponse(undefined);
          }
        );
        async = true;
      }
      else if (typeof response != "undefined")
      {
        sendResponse(response);
      }
    }

    return async;
  },

  /**
   * Function to be called when a particular message is received.
   *
   * @callback Port~messageCallback
   * @param {object} message
   * @param {object} sender
   * @return The callback can return undefined (no response),
   *         a value (response to be sent to sender immediately)
   *         or a promise (asynchronous response).
   */

  /**
   * Adds a callback for the specified message.
   *
   * The return value of the callback (if not undefined) is sent as response.
   * @param {string}   name
   * @param {Port~messageCallback} callback
   */
  on(name, callback)
  {
    this._eventEmitter.on(name, callback);
  },

  /**
   * Removes a callback for the specified message.
   *
   * @param {string}   name
   * @param {Port~messageCallback} callback
   */
  off(name, callback)
  {
    this._eventEmitter.off(name, callback);
  },

  /**
   * Disables the port and makes it stop listening to incoming messages.
   */
  disconnect()
  {
    ext.onMessage.removeListener(this._onMessage);
  }
};

/**
 * The default port to receive messages.
 *
 * @type {Port}
 */
exports.port = new Port();

/**
 * Creates a new port that is disconnected when the given window is unloaded.
 *
 * @param {Window} window
 * @return {Port}
 */
exports.getPort = function(window)
{
  let port = new Port();
  window.addEventListener("unload", () =>
  {
    port.disconnect();
  });
  return port;
};


return module.exports;
};

require.modules["notificationHelper"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module notificationHelper */

"use strict";

const {startIconAnimation, stopIconAnimation} = require("icon");
const {Utils} = require("utils");
const {Notification: NotificationStorage} = require("notification");
const {stringifyURL} = require("url");
const {initAntiAdblockNotification} = require("antiadblockInit");
const {Prefs} = require("prefs");

let activeNotification = null;
let activeButtons = null;
let defaultDisplayMethods = ["popup"];
let displayMethods = Object.create(null);
displayMethods.critical = ["icon", "notification", "popup"];
displayMethods.question = ["notification"];
displayMethods.normal = ["notification"];
displayMethods.relentless = ["notification"];
displayMethods.information = ["icon", "popup"];

function prepareNotificationIconAndPopup()
{
  let animateIcon = shouldDisplay("icon", activeNotification.type);
  activeNotification.onClicked = () =>
  {
    if (animateIcon)
      stopIconAnimation();
    notificationClosed();
  };
  if (animateIcon)
    startIconAnimation(activeNotification.type);
}

function getNotificationButtons(notificationType, message)
{
  let buttons = [];
  if (notificationType == "question")
  {
    buttons.push({
      type: "question",
      title: ext.i18n.getMessage("overlay_notification_button_yes")
    });
    buttons.push({
      type: "question",
      title: ext.i18n.getMessage("overlay_notification_button_no")
    });
  }
  else
  {
    let regex = /<a>(.*?)<\/a>/g;
    let match;
    while (match = regex.exec(message))
    {
      buttons.push({
        type: "link",
        title: match[1]
      });
    }

    // Chrome only allows two notification buttons so we need to fall back
    // to a single button to open all links if there are more than two.
    let maxButtons = (notificationType == "critical") ? 2 : 1;
    if (buttons.length > maxButtons)
    {
      buttons = [
        {
          type: "open-all",
          title: ext.i18n.getMessage("notification_open_all")
        }
      ];
    }
    if (!["critical", "relentless"].includes(notificationType))
    {
      buttons.push({
        type: "configure",
        title: ext.i18n.getMessage("notification_configure")
      });
    }
  }

  return buttons;
}

function openNotificationLinks()
{
  if (activeNotification.links)
  {
    for (let link of activeNotification.links)
      ext.pages.open(Utils.getDocLink(link));
  }
}

function notificationButtonClick(buttonIndex)
{
  if (!(activeButtons && buttonIndex in activeButtons))
    return;

  switch (activeButtons[buttonIndex].type)
  {
    case "link":
      ext.pages.open(Utils.getDocLink(activeNotification.links[buttonIndex]));
      break;
    case "open-all":
      openNotificationLinks();
      break;
    case "configure":
      Prefs.notifications_showui = true;
      ext.showOptions(page =>
      {
        page.sendMessage({
          type: "app.respond",
          action: "focusSection",
          args: ["notifications"]
        });
      });
      break;
    case "question":
      NotificationStorage.triggerQuestionListeners(activeNotification.id,
                                                   buttonIndex == 0);
      NotificationStorage.markAsShown(activeNotification.id);
      activeNotification.onClicked();
      break;
  }
}

function notificationClosed()
{
  activeNotification = null;
}

function initChromeNotifications()
{
  // Chrome hides notifications in notification center when clicked so
  // we need to clear them.
  function clearActiveNotification(notificationId)
  {
    if (activeNotification &&
        activeNotification.type != "question" &&
        !("links" in activeNotification))
      return;

    chrome.notifications.clear(notificationId, wasCleared =>
    {
      if (wasCleared)
        notificationClosed();
    });
  }

  chrome.notifications.onButtonClicked.addListener(
    (notificationId, buttonIndex) =>
    {
      notificationButtonClick(buttonIndex);
      clearActiveNotification(notificationId);
    }
  );
  chrome.notifications.onClicked.addListener(clearActiveNotification);
  chrome.notifications.onClosed.addListener(notificationClosed);
}

function showNotification(notification)
{
  if (activeNotification && activeNotification.id == notification.id)
    return;

  activeNotification = notification;
  if (shouldDisplay("notification", activeNotification.type))
  {
    let texts = NotificationStorage.getLocalizedTexts(notification);
    let title = texts.title || "";
    let message = (texts.message || "").replace(/<\/?(a|strong)>/g, "");
    let iconUrl = ext.getURL("icons/detailed/abp-128.png");
    let linkCount = (activeNotification.links || []).length;

    if ("notifications" in chrome)
    {
      activeButtons = getNotificationButtons(activeNotification.type,
                                             texts.message);
      chrome.notifications.create("", {
        type: "basic",
        title,
        iconUrl,
        message,
        buttons: activeButtons.map(button => ({title: button.title})),
        // We use the highest priority to prevent the notification
        // from closing automatically.
        priority: 2
      });
    }
    else if ("Notification" in window && activeNotification.type != "question")
    {
      if (linkCount > 0)
        message += " " + ext.i18n.getMessage("notification_without_buttons");

      let widget = new Notification(
        title,
        {
          lang: Utils.appLocale,
          dir: Utils.readingDirection,
          body: message,
          icon: iconUrl
        }
      );

      widget.addEventListener("click", openNotificationLinks);
      widget.addEventListener("close", notificationClosed);
    }
    else
    {
      message = title + "\n" + message;
      if (linkCount > 0)
        message += "\n\n" + ext.i18n.getMessage("notification_with_buttons");

      let approved = confirm(message);
      if (activeNotification.type == "question")
        notificationButtonClick(approved ? 0 : 1);
      else if (approved)
        openNotificationLinks();
    }
  }
  prepareNotificationIconAndPopup();

  if (notification.type !== "question")
    NotificationStorage.markAsShown(notification.id);
}

/**
 * Initializes the notification system.
 */
exports.initNotifications = () =>
{
  if ("notifications" in chrome)
    initChromeNotifications();
  initAntiAdblockNotification();
};

/**
 * Gets the active notification to be shown if any.
 *
 * @return {?object}
 */
exports.getActiveNotification = () => activeNotification;

let shouldDisplay =
/**
 * Determines whether a given display method should be used for a
 * specified notification type.
 *
 * @param {string} method Display method: icon, notification or popup
 * @param {string} notificationType
 * @return {boolean}
 */
exports.shouldDisplay = (method, notificationType) =>
{
  let methods = displayMethods[notificationType] || defaultDisplayMethods;
  return methods.includes(method);
};

ext.pages.onLoading.addListener(page =>
{
  NotificationStorage.showNext(stringifyURL(page.url));
});

NotificationStorage.addShowListener(showNotification);

return module.exports;
};

require.modules["prefs"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module prefs */

"use strict";

const {EventEmitter} = require("events");

const keyPrefix = "pref:";

let eventEmitter = new EventEmitter();
let overrides = Object.create(null);

/** @lends module:prefs.Prefs */
let defaults = Object.create(null);

/**
 * Only for compatibility with core code. Please do not change!
 *
 * @type {boolean}
 */
defaults.enabled = true;
/**
 * The application version as set during initialization. Used to detect updates.
 *
 * @type {string}
 */
defaults.currentVersion = "";
/**
 * Only for compatibility with core code. Please do not change!
 *
 * @type {string}
 */
defaults.data_directory = "";
/**
 * @see https://adblockplus.org/en/preferences#patternsbackups
 * @type {number}
 */
defaults.patternsbackups = 0;
/**
 * @see https://adblockplus.org/en/preferences#patternsbackupinterval
 * @type {number}
 */
defaults.patternsbackupinterval = 24;
/**
 * Only for compatibility with core code. Please do not change!
 *
 * @type {boolean}
 */
defaults.savestats = false;
/**
 * Only for compatibility with core code. Please do not change!
 *
 * @type {boolean}
 */
defaults.privateBrowsing = false;
/**
 * @see https://adblockplus.org/en/preferences#subscriptions_fallbackerrors
 * @type {number}
 */
defaults.subscriptions_fallbackerrors = 5;
/**
 * @see https://adblockplus.org/en/preferences#subscriptions_fallbackurl
 * @type {string}
 */
defaults.subscriptions_fallbackurl = "https://adblockplus.org/getSubscription?version=%VERSION%&url=%SUBSCRIPTION%&downloadURL=%URL%&error=%ERROR%&channelStatus=%CHANNELSTATUS%&responseStatus=%RESPONSESTATUS%";
/**
 * @see https://adblockplus.org/en/preferences#subscriptions_autoupdate
 * @type {boolean}
 */
defaults.subscriptions_autoupdate = true;
/**
 * @see https://adblockplus.org/en/preferences#subscriptions_exceptionsurl
 * @type {string}
 */
defaults.subscriptions_exceptionsurl = "https://easylist-downloads.adblockplus.org/exceptionrules.txt";
/**
 * @see https://adblockplus.org/en/preferences#subscriptions_antiadblockurl
 * @type {string}
 */
defaults.subscriptions_antiadblockurl = "https://easylist-downloads.adblockplus.org/antiadblockfilters.txt";
/**
 * @see https://adblockplus.org/en/preferences#documentation_link
 * @type {string}
 */
defaults.documentation_link = "https://adblockplus.org/redirect?link=%LINK%&lang=%LANG%";
/**
 * @see https://adblockplus.org/en/preferences#notificationdata
 * @type {object}
 */
defaults.notificationdata = {};
/**
 * @see https://adblockplus.org/en/preferences#notificationurl
 * @type {string}
 */
defaults.notificationurl = "https://notification.adblockplus.org/notification.json";
/**
 * The total number of requests blocked by the extension.
 *
 * @type {number}
 */
defaults.blocked_total = 0;
/**
 * Whether to show a badge in the toolbar icon indicating the number
 * of blocked ads.
 *
 * @type {boolean}
 */
defaults.show_statsinicon = true;
/**
 * Whether to show the number of blocked ads in the popup.
 *
 * @type {boolean}
 */
defaults.show_statsinpopup = true;
/**
 * Whether to show the "Block element" context menu entry.
 *
 * @type {boolean}
 */
defaults.shouldShowBlockElementMenu = true;
/**
 * Whether to collapse placeholders for blocked elements.
 *
 * @type {boolean}
 */
defaults.hidePlaceholders = true;

/**
 * Whether notification opt-out UI should be shown.
 * @type {boolean}
 */
defaults.notifications_showui = false;

/**
 * Determines whether data has been cleaned up after upgrading from the legacy
 * extension on Firefox.
 *
 * @type {boolean}
 */
defaults.data_cleanup_done = false;

/**
 * Notification categories to be ignored.
 *
 * @type {string[]}
 */
defaults.notifications_ignoredcategories = [];

/**
 * Whether to show the developer tools panel.
 *
 * @type {boolean}
 */
defaults.show_devtools_panel = true;

/**
 * Whether to suppress the first run page. This preference isn't
 * set by the extension but can be pre-configured externally.
 *
 * @see https://adblockplus.org/development-builds/suppressing-the-first-run-page-on-chrome
 * @type {boolean}
 */
defaults.suppress_first_run_page = false;

/**
 * Additonal subscriptions to be automatically added when the extension is
 * loaded. This preference isn't set by the extension but can be pre-configured
 * externally.
 *
 * @type {string[]}
 */
defaults.additional_subscriptions = [];

/**
  * @namespace
  * @static
  */
let Prefs = exports.Prefs = {
  /**
   * Adds a callback that is called when the
   * value of a specified preference changed.
   *
   * @param {string}   preference
   * @param {function} callback
   */
  on(preference, callback)
  {
    eventEmitter.on(preference, callback);
  },

  /**
   * Removes a callback for the specified preference.
   *
   * @param {string}   preference
   * @param {function} callback
   */
  off(preference, callback)
  {
    eventEmitter.off(preference, callback);
  },

  /**
   * A promise that is fullfilled when all preferences have been loaded.
   * Wait for this promise to be fulfilled before using preferences during
   * extension initialization.
   *
   * @type {Promise}
   */
  untilLoaded: null
};

function keyToPref(key)
{
  if (key.indexOf(keyPrefix) != 0)
    return null;

  return key.substr(keyPrefix.length);
}

function prefToKey(pref)
{
  return keyPrefix + pref;
}

function addPreference(pref)
{
  Object.defineProperty(Prefs, pref, {
    get() { return (pref in overrides ? overrides : defaults)[pref]; },
    set(value)
    {
      let defaultValue = defaults[pref];

      if (typeof value != typeof defaultValue)
        throw new Error("Attempt to change preference type");

      if (value == defaultValue)
      {
        delete overrides[pref];
        ext.storage.remove(prefToKey(pref));
      }
      else
      {
        overrides[pref] = value;
        ext.storage.set(prefToKey(pref), value);
      }
    },
    enumerable: true
  });
}

function init()
{
  let prefs = Object.keys(defaults);
  prefs.forEach(addPreference);

  let localLoaded = new Promise(resolve =>
  {
    ext.storage.get(prefs.map(prefToKey), items =>
    {
      for (let key in items)
        overrides[keyToPref(key)] = items[key];

      resolve();
    });
  });

  let managedLoaded = new Promise(resolve =>
  {
    if (require("info").platform == "chromium" && "managed" in chrome.storage)
    {
      chrome.storage.managed.get(null, items =>
      {
        // Opera doesn't support chrome.storage.managed, but instead simply
        // removing the API, Opera sets chrome.runtime.lastError when using it.
        // So we have to retrieve that error, to prevent it from showing up
        // in the console.
        chrome.runtime.lastError;

        for (let key in items)
          defaults[key] = items[key];

        resolve();
      });
    }
    else
    {
      resolve();
    }
  });

  function onLoaded()
  {
    ext.storage.onChanged.addListener(changes =>
    {
      for (let key in changes)
      {
        let pref = keyToPref(key);
        if (pref && pref in defaults)
        {
          let change = changes[key];
          if ("newValue" in change && change.newValue != defaults[pref])
            overrides[pref] = change.newValue;
          else
            delete overrides[pref];

          eventEmitter.emit(pref);
        }
      }
    });
  }

  Prefs.untilLoaded = Promise.all([localLoaded, managedLoaded]).then(onLoaded);
}

init();

return module.exports;
};

require.modules["punycode"] = function(module, exports)
{
/*
 * Copyright (C) 2011-2016 Mathias Bynens <https://mathiasbynens.be/>
 * Copyright (C) 2016-present eyeo GmbH (Minor modifications for compatibility.)
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

'use strict';

/** Highest positive signed 32-bit float value */
const maxInt = 2147483647; // aka. 0x7FFFFFFF or 2^31-1

/** Bootstring parameters */
const base = 36;
const tMin = 1;
const tMax = 26;
const skew = 38;
const damp = 700;
const initialBias = 72;
const initialN = 128; // 0x80
const delimiter = '-'; // '\x2D'

/** Regular expressions */
const regexPunycode = /^xn--/;
const regexNonASCII = /[^\x20-\x7E]/; // unprintable ASCII chars + non-ASCII chars
const regexSeparators = /[\x2E\u3002\uFF0E\uFF61]/g; // RFC 3490 separators

/** Error messages */
const errors = {
	'overflow': 'Overflow: input needs wider integers to process',
	'not-basic': 'Illegal input >= 0x80 (not a basic code point)',
	'invalid-input': 'Invalid input'
};

/** Convenience shortcuts */
const baseMinusTMin = base - tMin;
const floor = Math.floor;
const stringFromCharCode = String.fromCharCode;

/*--------------------------------------------------------------------------*/

/**
 * A generic error utility function.
 * @private
 * @param {String} type The error type.
 * @returns {Error} Throws a `RangeError` with the applicable error message.
 */
function error(type) {
	throw new RangeError(errors[type]);
}

/**
 * A generic `Array#map` utility function.
 * @private
 * @param {Array} array The array to iterate over.
 * @param {Function} callback The function that gets called for every array
 * item.
 * @returns {Array} A new array of values returned by the callback function.
 */
function map(array, fn) {
	const result = [];
	let length = array.length;
	while (length--) {
		result[length] = fn(array[length]);
	}
	return result;
}

/**
 * A simple `Array#map`-like wrapper to work with domain name strings or email
 * addresses.
 * @private
 * @param {String} domain The domain name or email address.
 * @param {Function} callback The function that gets called for every
 * character.
 * @returns {Array} A new string of characters returned by the callback
 * function.
 */
function mapDomain(string, fn) {
	const parts = string.split('@');
	let result = '';
	if (parts.length > 1) {
		// In email addresses, only the domain name should be punycoded. Leave
		// the local part (i.e. everything up to `@`) intact.
		result = parts[0] + '@';
		string = parts[1];
	}
	// Avoid `split(regex)` for IE8 compatibility. See #17.
	string = string.replace(regexSeparators, '\x2E');
	const labels = string.split('.');
	const encoded = map(labels, fn).join('.');
	return result + encoded;
}

/**
 * Creates an array containing the numeric code points of each Unicode
 * character in the string. While JavaScript uses UCS-2 internally,
 * this function will convert a pair of surrogate halves (each of which
 * UCS-2 exposes as separate characters) into a single code point,
 * matching UTF-16.
 * @see `punycode.ucs2.encode`
 * @see <https://mathiasbynens.be/notes/javascript-encoding>
 * @memberOf punycode.ucs2
 * @name decode
 * @param {String} string The Unicode input string (UCS-2).
 * @returns {Array} The new array of code points.
 */
function ucs2decode(string) {
	const output = [];
	let counter = 0;
	const length = string.length;
	while (counter < length) {
		const value = string.charCodeAt(counter++);
		if (value >= 0xD800 && value <= 0xDBFF && counter < length) {
			// It's a high surrogate, and there is a next character.
			const extra = string.charCodeAt(counter++);
			if ((extra & 0xFC00) == 0xDC00) { // Low surrogate.
				output.push(((value & 0x3FF) << 10) + (extra & 0x3FF) + 0x10000);
			} else {
				// It's an unmatched surrogate; only append this code unit, in case the
				// next code unit is the high surrogate of a surrogate pair.
				output.push(value);
				counter--;
			}
		} else {
			output.push(value);
		}
	}
	return output;
}

/**
 * Creates a string based on an array of numeric code points.
 * @see `punycode.ucs2.decode`
 * @memberOf punycode.ucs2
 * @name encode
 * @param {Array} codePoints The array of numeric code points.
 * @returns {String} The new Unicode string (UCS-2).
 */
const ucs2encode = array => String.fromCodePoint.apply(null, array);

/**
 * Converts a basic code point into a digit/integer.
 * @see `digitToBasic()`
 * @private
 * @param {Number} codePoint The basic numeric code point value.
 * @returns {Number} The numeric value of a basic code point (for use in
 * representing integers) in the range `0` to `base - 1`, or `base` if
 * the code point does not represent a value.
 */
const basicToDigit = function(codePoint) {
	if (codePoint - 0x30 < 0x0A) {
		return codePoint - 0x16;
	}
	if (codePoint - 0x41 < 0x1A) {
		return codePoint - 0x41;
	}
	if (codePoint - 0x61 < 0x1A) {
		return codePoint - 0x61;
	}
	return base;
};

/**
 * Converts a digit/integer into a basic code point.
 * @see `basicToDigit()`
 * @private
 * @param {Number} digit The numeric value of a basic code point.
 * @returns {Number} The basic code point whose value (when used for
 * representing integers) is `digit`, which needs to be in the range
 * `0` to `base - 1`. If `flag` is non-zero, the uppercase form is
 * used; else, the lowercase form is used. The behavior is undefined
 * if `flag` is non-zero and `digit` has no uppercase form.
 */
const digitToBasic = function(digit, flag) {
	//  0..25 map to ASCII a..z or A..Z
	// 26..35 map to ASCII 0..9
	return digit + 22 + 75 * (digit < 26) - ((flag != 0) << 5);
};

/**
 * Bias adaptation function as per section 3.4 of RFC 3492.
 * https://tools.ietf.org/html/rfc3492#section-3.4
 * @private
 */
const adapt = function(delta, numPoints, firstTime) {
	let k = 0;
	delta = firstTime ? floor(delta / damp) : delta >> 1;
	delta += floor(delta / numPoints);
	for (/* no initialization */; delta > baseMinusTMin * tMax >> 1; k += base) {
		delta = floor(delta / baseMinusTMin);
	}
	return floor(k + (baseMinusTMin + 1) * delta / (delta + skew));
};

/**
 * Converts a Punycode string of ASCII-only symbols to a string of Unicode
 * symbols.
 * @memberOf punycode
 * @param {String} input The Punycode string of ASCII-only symbols.
 * @returns {String} The resulting string of Unicode symbols.
 */
const decode = function(input) {
	// Don't use UCS-2.
	const output = [];
	const inputLength = input.length;
	let i = 0;
	let n = initialN;
	let bias = initialBias;

	// Handle the basic code points: let `basic` be the number of input code
	// points before the last delimiter, or `0` if there is none, then copy
	// the first basic code points to the output.

	let basic = input.lastIndexOf(delimiter);
	if (basic < 0) {
		basic = 0;
	}

	for (let j = 0; j < basic; ++j) {
		// if it's not a basic code point
		if (input.charCodeAt(j) >= 0x80) {
			error('not-basic');
		}
		output.push(input.charCodeAt(j));
	}

	// Main decoding loop: start just after the last delimiter if any basic code
	// points were copied; start at the beginning otherwise.

	for (let index = basic > 0 ? basic + 1 : 0; index < inputLength; /* no final expression */) {

		// `index` is the index of the next character to be consumed.
		// Decode a generalized variable-length integer into `delta`,
		// which gets added to `i`. The overflow checking is easier
		// if we increase `i` as we go, then subtract off its starting
		// value at the end to obtain `delta`.
		let oldi = i;
		for (let w = 1, k = base; /* no condition */; k += base) {

			if (index >= inputLength) {
				error('invalid-input');
			}

			const digit = basicToDigit(input.charCodeAt(index++));

			if (digit >= base || digit > floor((maxInt - i) / w)) {
				error('overflow');
			}

			i += digit * w;
			const t = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias);

			if (digit < t) {
				break;
			}

			const baseMinusT = base - t;
			if (w > floor(maxInt / baseMinusT)) {
				error('overflow');
			}

			w *= baseMinusT;

		}

		const out = output.length + 1;
		bias = adapt(i - oldi, out, oldi == 0);

		// `i` was supposed to wrap around from `out` to `0`,
		// incrementing `n` each time, so we'll fix that now:
		if (floor(i / out) > maxInt - n) {
			error('overflow');
		}

		n += floor(i / out);
		i %= out;

		// Insert `n` at position `i` of the output.
		output.splice(i++, 0, n);

	}

	return String.fromCodePoint.apply(null, output);
};

/**
 * Converts a string of Unicode symbols (e.g. a domain name label) to a
 * Punycode string of ASCII-only symbols.
 * @memberOf punycode
 * @param {String} input The string of Unicode symbols.
 * @returns {String} The resulting Punycode string of ASCII-only symbols.
 */
const encode = function(input) {
	const output = [];

	// Convert the input in UCS-2 to an array of Unicode code points.
	input = ucs2decode(input);

	// Cache the length.
	let inputLength = input.length;

	// Initialize the state.
	let n = initialN;
	let delta = 0;
	let bias = initialBias;

	// Handle the basic code points.
	for (let currentValue of input) {
		if (currentValue < 0x80) {
			output.push(stringFromCharCode(currentValue));
		}
	}

	let basicLength = output.length;
	let handledCPCount = basicLength;

	// `handledCPCount` is the number of code points that have been handled;
	// `basicLength` is the number of basic code points.

	// Finish the basic string with a delimiter unless it's empty.
	if (basicLength) {
		output.push(delimiter);
	}

	// Main encoding loop:
	while (handledCPCount < inputLength) {

		// All non-basic code points < n have been handled already. Find the next
		// larger one:
		let m = maxInt;
		for (let currentValue of input) {
			if (currentValue >= n && currentValue < m) {
				m = currentValue;
			}
		}

		// Increase `delta` enough to advance the decoder's <n,i> state to <m,0>,
		// but guard against overflow.
		const handledCPCountPlusOne = handledCPCount + 1;
		if (m - n > floor((maxInt - delta) / handledCPCountPlusOne)) {
			error('overflow');
		}

		delta += (m - n) * handledCPCountPlusOne;
		n = m;

		for (let currentValue of input) {
			if (currentValue < n && ++delta > maxInt) {
				error('overflow');
			}
			if (currentValue == n) {
				// Represent delta as a generalized variable-length integer.
				let q = delta;
				for (let k = base; /* no condition */; k += base) {
					const t = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias);
					if (q < t) {
						break;
					}
					const qMinusT = q - t;
					const baseMinusT = base - t;
					output.push(
						stringFromCharCode(digitToBasic(t + qMinusT % baseMinusT, 0))
					);
					q = floor(qMinusT / baseMinusT);
				}

				output.push(stringFromCharCode(digitToBasic(q, 0)));
				bias = adapt(delta, handledCPCountPlusOne, handledCPCount == basicLength);
				delta = 0;
				++handledCPCount;
			}
		}

		++delta;
		++n;

	}
	return output.join('');
};

/**
 * Converts a Punycode string representing a domain name or an email address
 * to Unicode. Only the Punycoded parts of the input will be converted, i.e.
 * it doesn't matter if you call it on a string that has already been
 * converted to Unicode.
 * @memberOf punycode
 * @param {String} input The Punycoded domain name or email address to
 * convert to Unicode.
 * @returns {String} The Unicode representation of the given Punycode
 * string.
 */
const toUnicode = function(input) {
	return mapDomain(input, function(string) {
		return regexPunycode.test(string)
			? decode(string.slice(4).toLowerCase())
			: string;
	});
};

/**
 * Converts a Unicode string representing a domain name or an email address to
 * Punycode. Only the non-ASCII parts of the domain name will be converted,
 * i.e. it doesn't matter if you call it with a domain that's already in
 * ASCII.
 * @memberOf punycode
 * @param {String} input The domain name or email address to convert, as a
 * Unicode string.
 * @returns {String} The Punycode representation of the given domain name or
 * email address.
 */
const toASCII = function(input) {
	return mapDomain(input, function(string) {
		return regexNonASCII.test(string)
			? 'xn--' + encode(string)
			: string;
	});
};

/*--------------------------------------------------------------------------*/

/** Define the public API */
module.exports = {
	/**
	 * A string representing the current Punycode.js version number.
	 * @memberOf punycode
	 * @type String
	 */
	'version': '2.0.0',
	/**
	 * An object of methods to convert from JavaScript's internal character
	 * representation (UCS-2) to Unicode code points, and back.
	 * @see <https://mathiasbynens.be/notes/javascript-encoding>
	 * @memberOf punycode
	 * @type Object
	 */
	'ucs2': {
		'decode': ucs2decode,
		'encode': ucs2encode
	},
	'decode': decode,
	'encode': encode,
	'toASCII': toASCII,
	'toUnicode': toUnicode
};

return module.exports;
};

require.modules["requestBlocker"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module requestBlocker */

"use strict";

const {Filter, RegExpFilter, BlockingFilter} = require("filterClasses");
const {Subscription} = require("subscriptionClasses");
const {defaultMatcher} = require("matcher");
const {FilterNotifier} = require("filterNotifier");
const {Prefs} = require("prefs");
const {checkWhitelisted, getKey} = require("whitelisting");
const {stringifyURL, extractHostFromFrame, isThirdParty} = require("url");
const {port} = require("messaging");
const devtools = require("devtools");

// Chrome can't distinguish between OBJECT_SUBREQUEST and OBJECT requests.
if (!chrome.webRequest.ResourceType ||
    !("OBJECT_SUBREQUEST" in chrome.webRequest.ResourceType))
{
  RegExpFilter.typeMap.OBJECT_SUBREQUEST = RegExpFilter.typeMap.OBJECT;
}

// Map of content types reported by the browser to the respecitve content types
// used by Adblock Plus. Other content types are simply mapped to OTHER.
let resourceTypes = new Map(function*()
{
  for (let type in RegExpFilter.typeMap)
    yield [type.toLowerCase(), type];

  yield ["sub_frame", "SUBDOCUMENT"];

  // Treat navigator.sendBeacon() the same as <a ping>, it's essentially the
  // same concept - merely generalized.
  yield ["beacon", "PING"];

  // Treat <img srcset> and <picture> the same as other images.
  yield ["imageset", "IMAGE"];
}());

function onBeforeRequestAsync(page, url, type, docDomain,
                              thirdParty, sitekey,
                              specificOnly, filter)
{
  if (filter)
    FilterNotifier.emit("filter.hitCount", filter, 0, 0, page);

  if (devtools)
  {
    devtools.logRequest(
      page, url, type, docDomain,
      thirdParty, sitekey,
      specificOnly, filter
    );
  }
}

ext.webRequest.onBeforeRequest.addListener((url, type, page, frame) =>
{
  let docDomain = null;
  let sitekey = null;
  let specificOnly = false;
  let thirdParty = false;
  let urlString = stringifyURL(url);


  if (frame && page)
  {
    if (checkWhitelisted(page, frame))
      return true;

    docDomain = extractHostFromFrame(frame);
    sitekey = getKey(page, frame);
    thirdParty = isThirdParty(url, docDomain);
    specificOnly = !!checkWhitelisted(page, frame,
                                      RegExpFilter.typeMap.GENERICBLOCK);
  }

  let mappedType = resourceTypes.get(type) || "OTHER";

  let filter = defaultMatcher.matchesAny(
    urlString, RegExpFilter.typeMap[mappedType],
    docDomain, thirdParty, sitekey, specificOnly
  );

  setTimeout(onBeforeRequestAsync, 0, page, urlString,
                                      mappedType, docDomain,
                                      thirdParty, sitekey,
                                      specificOnly, filter);

  return !(filter instanceof BlockingFilter);
});

port.on("filters.collapse", (message, sender) =>
{
  if (checkWhitelisted(sender.page, sender.frame))
    return false;

  let typeMask = RegExpFilter.typeMap[message.mediatype];
  let documentHost = extractHostFromFrame(sender.frame);
  let sitekey = getKey(sender.page, sender.frame);
  let blocked = false;

  let specificOnly = checkWhitelisted(
    sender.page, sender.frame,
    RegExpFilter.typeMap.GENERICBLOCK
  );

  for (let url of message.urls)
  {
    let urlObj = new URL(url, message.baseURL);
    let filter = defaultMatcher.matchesAny(
      stringifyURL(urlObj),
      typeMask, documentHost,
      isThirdParty(urlObj, documentHost),
      sitekey, specificOnly
    );

    if (filter instanceof BlockingFilter)
    {
      if (filter.collapse != null)
        return filter.collapse;
      blocked = true;
    }
  }

  return blocked && Prefs.hidePlaceholders;
});

let ignoreFilterNotifications = false;

function onFilterChange(arg, isDisabledAction)
{
  // Avoid triggering filters.behaviorChanged multiple times
  // when multiple filter hanges happen at the same time.
  if (ignoreFilterNotifications)
    return;

  // Ignore disabled subscriptions and filters, unless they just got
  // disabled, otherwise they have no effect on the handler behavior.
  if (arg && arg.disabled && !isDisabledAction)
    return;

  // Ignore empty subscriptions. This includes subscriptions
  // that have just been added, but not downloaded yet.
  if (arg instanceof Subscription && arg.filters.length == 0)
    return;

  // Ignore all types of filters but request filters,
  // only these have an effect on the handler behavior.
  if (arg instanceof Filter && !(arg instanceof RegExpFilter))
    return;

  ignoreFilterNotifications = true;
  setTimeout(() =>
  {
    ignoreFilterNotifications = false;
    ext.webRequest.handlerBehaviorChanged();
    FilterNotifier.emit("filter.behaviorChanged");
  });
}

FilterNotifier.on("subscription.added", onFilterChange);
FilterNotifier.on("subscription.removed", onFilterChange);
FilterNotifier.on("subscription.updated", onFilterChange);
FilterNotifier.on("subscription.disabled", arg => onFilterChange(arg, true));
FilterNotifier.on("filter.added", onFilterChange);
FilterNotifier.on("filter.removed", onFilterChange);
FilterNotifier.on("filter.disabled", arg => onFilterChange(arg, true));
FilterNotifier.on("load", onFilterChange);

port.on("request.blockedByWrapper", (msg, sender) =>
{
  // Chrome 58 onwards directly supports WebSocket blocking, so we can ignore
  // messages from the wrapper here (see https://crbug.com/129353). Hopefully
  // WebRTC will be supported soon too (see https://crbug.com/707683).
  // Edge supports neither webRequest.ResourceType nor WebSocket blocking yet:
  // https://developer.microsoft.com/en-us/microsoft-edge/platform/issues/10297376/
  if (chrome.webRequest.ResourceType &&
      (msg.requestType.toUpperCase() in chrome.webRequest.ResourceType))
  {
    return false;
  }

  return ext.webRequest.onBeforeRequest._dispatch(
     new URL(msg.url),
     msg.requestType,
     sender.page,
     sender.frame
  ).includes(false);
});

return module.exports;
};

require.modules["stats"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module stats */

"use strict";

const {Prefs} = require("prefs");
const {BlockingFilter} = require("filterClasses");
const {FilterNotifier} = require("filterNotifier");

const badgeColor = "#646464";
let blockedPerPage = new ext.PageMap();

/**
 * Gets the number of requests blocked on the given page.
 *
 * @param  {Page} page
 * @return {Number}
 */
exports.getBlockedPerPage = page => blockedPerPage.get(page) || 0;

// Chrome automatically clears the browser action badge text when the URL of
// the tab is updated, but Firefox doesn't.
// https://bugzilla.mozilla.org/show_bug.cgi?id=1395074
ext.pages.onLoading.addListener(page =>
{
  if (!blockedPerPage.get(page))
    page.browserAction.setBadge();
});

FilterNotifier.on("filter.hitCount", (filter, newValue, oldValue, page) =>
{
  if (!(filter instanceof BlockingFilter) || !page)
    return;

  Prefs.blocked_total++;

  let blocked = blockedPerPage.get(page) || 0;
  blockedPerPage.set(page, ++blocked);

  // Update number in icon
  if (Prefs.show_statsinicon)
  {
    page.browserAction.setBadge({
      color: badgeColor,
      number: blocked
    });
  }
});

Prefs.on("show_statsinicon", () =>
{
  ext.pages.query({}, pages =>
  {
    for (let page of pages)
    {
      let badge = null;

      if (Prefs.show_statsinicon)
      {
        let blocked = blockedPerPage.get(page);
        if (blocked)
        {
          badge = {
            color: badgeColor,
            number: blocked
          };
        }
      }

      page.browserAction.setBadge(badge);
    }
  });
});

return module.exports;
};

require.modules["subscriptionInit"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module subscriptionInit */

"use strict";

const {Subscription, DownloadableSubscription,
       SpecialSubscription} = require("subscriptionClasses");
const {FilterStorage} = require("filterStorage");
const {FilterNotifier} = require("filterNotifier");
const {Prefs} = require("prefs");
const {Synchronizer} = require("synchronizer");
const {Utils} = require("utils");
const {initNotifications} = require("notificationHelper");

let firstRun;
let subscriptionsCallback = null;

/**
 * If there aren't any filters, the default subscriptions are added.
 * However, if patterns.ini already did exist and/or any preference
 * is set to a non-default value, this indicates that this isn't the
 * first run, but something went wrong.
 *
 * This function detects the first run, and makes sure that the user
 * gets notified (on the first run page) if the data appears incomplete
 * and therefore will be reinitialized.
 */
function detectFirstRun()
{
  firstRun = FilterStorage.subscriptions.length == 0;

  if (firstRun && (!FilterStorage.firstRun || Prefs.currentVersion))
    exports.reinitialized = true;

  Prefs.currentVersion = require("info").addonVersion;
}

/**
 * Determines whether to add the default ad blocking subscription.
 * Returns true, if there are no filter subscriptions besides those
 * other subscriptions added automatically, and no custom filters.
 *
 * On first run, this logic should always result in true since there
 * is no data and therefore no subscriptions. But it also causes the
 * default ad blocking subscription to be added again after some
 * data corruption or misconfiguration.
 *
 * @return {boolean}
 */
function shouldAddDefaultSubscription()
{
  for (let subscription of FilterStorage.subscriptions)
  {
    if (subscription instanceof DownloadableSubscription &&
        subscription.url != Prefs.subscriptions_exceptionsurl &&
        subscription.url != Prefs.subscriptions_antiadblockurl)
      return false;

    if (subscription instanceof SpecialSubscription &&
        subscription.filters.length > 0)
      return false;
  }

  return true;
}

/**
 * Gets the filter subscriptions to be added when the extnesion is loaded.
 *
 * @return {Promise|Subscription[]}
 */
function getSubscriptions()
{
  let subscriptions = [];

  // Add pre-configured subscriptions
  for (let url of Prefs.additional_subscriptions)
    subscriptions.push(Subscription.fromURL(url));

  // Add "acceptable ads" and "anti-adblock messages" subscriptions
  if (firstRun)
  {
    let acceptableAdsSubscription = Subscription.fromURL(
      Prefs.subscriptions_exceptionsurl
    );
    acceptableAdsSubscription.title = "Allow non-intrusive advertising";
    subscriptions.push(acceptableAdsSubscription);

    let antiAdblockSubscription = Subscription.fromURL(
      Prefs.subscriptions_antiadblockurl
    );
    antiAdblockSubscription.disabled = true;
    subscriptions.push(antiAdblockSubscription);
  }

  // Add default ad blocking subscription (e.g. EasyList)
  if (shouldAddDefaultSubscription())
  {
    return fetch("subscriptions.xml")
      .then(response => response.text())
      .then(text =>
      {
        let doc = new DOMParser().parseFromString(text, "application/xml");
        let nodes = doc.getElementsByTagName("subscription");

        let node = Utils.chooseFilterSubscription(nodes);
        if (node)
        {
          let url = node.getAttribute("url");
          if (url)
          {
            let subscription = Subscription.fromURL(url);
            subscription.disabled = false;
            subscription.title = node.getAttribute("title");
            subscription.homepage = node.getAttribute("homepage");
            subscriptions.push(subscription);
          }
        }

        return subscriptions;
      });
  }

  return subscriptions;
}

function finishInitialization(subscriptions)
{
  if (subscriptionsCallback)
    subscriptions = subscriptionsCallback(subscriptions);

  for (let subscription of subscriptions)
  {
    FilterStorage.addSubscription(subscription);
    if (subscription instanceof DownloadableSubscription &&
        !subscription.lastDownload)
      Synchronizer.execute(subscription);
  }

  if (firstRun && !Prefs.suppress_first_run_page)
    ext.pages.open(ext.getURL("firstRun.html"));

  initNotifications();
}

Promise.all([FilterNotifier.once("load"),
             Prefs.untilLoaded]).then(detectFirstRun)
                                .then(getSubscriptions)
                                .then(finishInitialization);

/**
 * Indicates whether the default filter subscriptions have been added
 * again because there weren't any subscriptions even though this wasn't
 * the first run.
 *
 * @type {boolean}
 */
exports.reinitialized = false;

/**
 * Sets a callback that is called with an array of subscriptions to be added
 * during initialization. The callback must return an array of subscriptions
 * that will effectively be added.
 *
 * @param {function} callback
 */
exports.setSubscriptionsCallback = callback =>
{
  subscriptionsCallback = callback;
};

return module.exports;
};

require.modules["tldjs"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/* global publicSuffixes */

/** @module tldjs */

"use strict";

/**
 * Get the base domain for given hostname.
 *
 * @param {string} hostname
 * @return {string}
 */
exports.getDomain = hostname =>
{
  let bits = hostname.split(".");
  let cutoff = bits.length - 2;

  for (let i = 0; i < bits.length; i++)
  {
    let offset = publicSuffixes[bits.slice(i).join(".")];

    if (typeof offset != "undefined")
    {
      cutoff = i - offset;
      break;
    }
  }

  if (cutoff <= 0)
    return hostname;

  return bits.slice(cutoff).join(".");
};

return module.exports;
};

require.modules["url"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module url */

"use strict";

const {getDomain} = require("tldjs");
const punycode = require("punycode");

let getDecodedHostname =
/**
 * Gets the IDN-decoded hostname from a URL object.
 *
 * @param {URL} url
 * @return {string}
 * @static
 */
exports.getDecodedHostname = url =>
{
  let {hostname} = url;

  if (hostname.indexOf("xn--") == -1)
    return hostname;

  return punycode.toUnicode(hostname);
};

/**
 * Gets the IDN-decoded hostname from the URL of a frame.
 * If the URL don't have host information (like "about:blank"
 * and "data:" URLs) it falls back to the parent frame.
 *
 * @param {Frame} frame
 * @return {string}
 */
exports.extractHostFromFrame = frame =>
{
  for (; frame; frame = frame.parent)
  {
    let hostname = getDecodedHostname(frame.url);
    if (hostname)
      return hostname;
  }

  return "";
};

/**
 * Converts a URL object into a string. For HTTP(S) URLs
 * the hostname gets IDN-decoded and the hash is stripped.
 *
 * @param {URL} url
 * @return {string}
 */
exports.stringifyURL = url =>
{
  let {protocol, href} = url;

  if (protocol == "http:" || protocol == "https:")
  {
    let {hostname} = url;
    if (hostname.indexOf("xn--") != -1)
      href = href.replace(hostname, punycode.toUnicode(hostname));

    let hash = href.indexOf("#");
    if (hash != -1)
      href = href.substr(0, hash);
  }

  return href;
};

function isDomain(hostname)
{
  // No hostname or IPv4 address, also considering hexadecimal octets.
  if (/^((0x[\da-f]+|\d+)(\.|$))*$/i.test(hostname))
    return false;

  // IPv6 address. Since there can't be colons in domains, we can
  // just check whether there are any colons to exclude IPv6 addresses.
  return hostname.indexOf(":") == -1;
}

/**
 * Checks whether the request's origin is different from the document's origin.
 *
 * @param {URL}    url           The request URL
 * @param {string} documentHost  The IDN-decoded hostname of the document
 * @return {Boolean}
 */
exports.isThirdParty = (url, documentHost) =>
{
  let requestHost = getDecodedHostname(url).replace(/\.+$/, "");
  documentHost = documentHost.replace(/\.+$/, "");

  if (requestHost == documentHost)
    return false;

  if (!isDomain(requestHost) || !isDomain(documentHost))
    return true;

  return getDomain(requestHost) != getDomain(documentHost);
};

return module.exports;
};

require.modules["utils"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

let Utils = exports.Utils = {
  systemPrincipal: null,
  getString(id)
  {
    return ext.i18n.getMessage("global_" + id);
  },
  runAsync(callback)
  {
    if (document.readyState == "loading")
    {
      // Make sure to not run asynchronous actions before all
      // scripts loaded. This caused issues on Opera in the past.
      let onDOMContentLoaded = () =>
      {
        document.removeEventListener("DOMContentLoaded", onDOMContentLoaded);
        callback();
      };
      document.addEventListener("DOMContentLoaded", onDOMContentLoaded);
    }
    else
    {
      setTimeout(callback, 0);
    }
  },
  get appLocale()
  {
    let locale = ext.i18n.getUILanguage();
    Object.defineProperty(this, "appLocale", {value: locale, enumerable: true});
    return this.appLocale;
  },
  get readingDirection()
  {
    let direction = ext.i18n.getMessage("@@bidi_dir");
    // This fallback is only necessary for Microsoft Edge
    if (!direction)
      direction = /^(?:ar|fa|he|ug|ur)\b/.test(this.appLocale) ? "rtl" : "ltr";
    Object.defineProperty(
      this,
      "readingDirection",
      {value: direction, enumerable: true}
    );
    return this.readingDirection;
  },
  generateChecksum(lines)
  {
    // We cannot calculate MD5 checksums yet :-(
    return null;
  },
  checkLocalePrefixMatch(prefixes)
  {
    if (!prefixes)
      return null;

    for (let prefix of prefixes.split(","))
    {
      if (new RegExp("^" + prefix + "\\b").test(this.appLocale))
        return prefix;
    }

    return null;
  },

  chooseFilterSubscription(subscriptions)
  {
    let selectedItem = null;
    let selectedPrefix = null;
    let matchCount = 0;
    for (let subscription of subscriptions)
    {
      if (!selectedItem)
        selectedItem = subscription;

      let prefix = Utils.checkLocalePrefixMatch(
        subscription.getAttribute("prefixes")
      );
      if (prefix)
      {
        if (!selectedPrefix || selectedPrefix.length < prefix.length)
        {
          selectedItem = subscription;
          selectedPrefix = prefix;
          matchCount = 1;
        }
        else if (selectedPrefix && selectedPrefix.length == prefix.length)
        {
          matchCount++;

          // If multiple items have a matching prefix of the same length:
          // Select one of the items randomly, probability should be the same
          // for all items. So we replace the previous match here with
          // probability 1/N (N being the number of matches).
          if (Math.random() * matchCount < 1)
          {
            selectedItem = subscription;
            selectedPrefix = prefix;
          }
        }
      }
    }
    return selectedItem;
  },

  getDocLink(linkID)
  {
    let docLink = require("prefs").Prefs.documentation_link;
    return docLink.replace(/%LINK%/g, linkID)
                  .replace(/%LANG%/g, Utils.appLocale);
  },

  yield()
  {
  }
};

return module.exports;
};

require.modules["whitelisting"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module whitelisting */

"use strict";

const {defaultMatcher} = require("matcher");
const {RegExpFilter} = require("filterClasses");
const {FilterNotifier} = require("filterNotifier");
const {stringifyURL, getDecodedHostname,
       extractHostFromFrame, isThirdParty} = require("url");
const {port} = require("messaging");
const devtools = require("devtools");
const {verifySignature} = require("rsa");

let sitekeys = new ext.PageMap();

function match(page, url, typeMask, docDomain, sitekey)
{
  let thirdParty = !!docDomain && isThirdParty(url, docDomain);
  let urlString = stringifyURL(url);

  if (!docDomain)
    docDomain = getDecodedHostname(url);

  let filter = defaultMatcher.whitelist.matchesAny(
    urlString, typeMask, docDomain, thirdParty, sitekey
  );

  if (filter && devtools)
  {
    devtools.logWhitelistedDocument(
      page, urlString, typeMask, docDomain, filter
    );
  }

  return filter;
}

let checkWhitelisted =
/**
 * Gets the active whitelisting filter for the document associated
 * with the given page/frame, or null if it's not whitelisted.
 *
 * @param {Page}   page
 * @param {Frame}  [frame]
 * @param {number} [typeMask=RegExpFilter.typeMap.DOCUMENT]
 * @return {?WhitelistFilter}
 */
exports.checkWhitelisted = (page, frame, typeMask) =>
{
  if (typeof typeMask == "undefined")
    typeMask = RegExpFilter.typeMap.DOCUMENT;

  if (frame)
  {
    let filter = null;

    while (frame && !filter)
    {
      let {parent} = frame;
      let docDomain = extractHostFromFrame(parent);
      let sitekey = getKey(page, frame);

      filter = match(page, frame.url, typeMask, docDomain, sitekey);
      frame = parent;
    }

    return filter;
  }

  return match(page, page.url, typeMask);
};

port.on("filters.isPageWhitelisted", (message, sender) =>
{
  return !!checkWhitelisted(sender.page);
});

function revalidateWhitelistingState(page)
{
  FilterNotifier.emit(
    "page.WhitelistingStateRevalidate",
    page, checkWhitelisted(page)
  );
}

FilterNotifier.on("filter.behaviorChanged", () =>
{
  ext.pages.query({}, pages =>
  {
    for (let page of pages)
      revalidateWhitelistingState(page);
  });
});

ext.pages.onLoading.addListener(revalidateWhitelistingState);

let getKey =
/**
 * Gets the public key, previously recorded for the given page
 * and frame, to be considered for the $sitekey filter option.
 *
 * @param {Page}  page
 * @param {Frame} frame
 * @return {string}
 */
exports.getKey = (page, frame) =>
{
  let keys = sitekeys.get(page);
  if (!keys)
    return null;

  for (; frame != null; frame = frame.parent)
  {
    let key = keys.get(stringifyURL(frame.url));
    if (key)
      return key;
  }

  return null;
};

function checkKey(token, url)
{
  let parts = token.split("_");
  if (parts.length < 2)
    return false;

  let key = parts[0].replace(/=/g, "");
  let signature = parts[1];
  let data = url.pathname + url.search + "\0" +
             url.host + "\0" +
             window.navigator.userAgent;
  if (!verifySignature(key, signature, data))
    return false;

  return key;
}

function recordKey(key, page, url)
{
  let keys = sitekeys.get(page);
  if (!keys)
  {
    keys = new Map();
    sitekeys.set(page, keys);
  }
  keys.set(stringifyURL(url), key);
}

port.on("filters.addKey", (message, sender) =>
{
  let key = checkKey(message.token, sender.frame.url);
  if (key)
    recordKey(key, sender.page, sender.frame.url);
});

function onHeadersReceived(details)
{
  let page = new ext.Page({id: details.tabId});

  for (let header of details.responseHeaders)
  {
    if (header.name.toLowerCase() == "x-adblock-key" && header.value)
    {
      let url = new URL(details.url);
      let key = checkKey(header.value, url);
      if (key)
      {
        recordKey(key, page, url);
        break;
      }
    }
  }
}

if (typeof chrome == "object")
{
  chrome.webRequest.onHeadersReceived.addListener(
    onHeadersReceived,
    {
      urls: ["http://*/*", "https://*/*"],
      types: ["main_frame", "sub_frame"]
    },
    ["responseHeaders"]
  );
}

return module.exports;
};

require.modules["devtools"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

const {RegExpFilter,
       WhitelistFilter,
       ElemHideFilter} = require("filterClasses");
const {SpecialSubscription} = require("subscriptionClasses");
const {FilterStorage} = require("filterStorage");
const {defaultMatcher} = require("matcher");
const {FilterNotifier} = require("filterNotifier");
const {extractHostFromFrame} = require("url");
const {port} = require("messaging");

const nonRequestTypes = ["DOCUMENT", "ELEMHIDE", "GENERICBLOCK", "GENERICHIDE"];

// Mapping of inspected tabs to their devpanel page
// and recorded items. We can't use a PageMap here,
// because data must persist after navigation/reload.
let panels = new Map();

function isActivePanel(panel)
{
  return panel && !panel.reload && !panel.reloading;
}

function getActivePanel(page)
{
  let panel = panels.get(page.id);
  if (isActivePanel(panel))
    return panel;
  return null;
}

function getFilterInfo(filter)
{
  if (!filter)
    return null;

  let userDefined = false;
  let subscriptionTitle = null;

  for (let subscription of filter.subscriptions)
  {
    if (!subscription.disabled)
    {
      if (subscription instanceof SpecialSubscription)
        userDefined = true;
      else
        subscriptionTitle = subscription.title;
    }
  }

  return {
    text: filter.text,
    whitelisted: filter instanceof WhitelistFilter,
    userDefined,
    subscription: subscriptionTitle
  };
}

function hasRecord(panel, request, filter)
{
  return panel.records.some(record =>
    record.request.url == request.url &&
    record.request.docDomain == request.docDomain &&

    // Ignore partial (e.g. ELEMHIDE) whitelisting if there is already
    // a DOCUMENT exception which disables all means of blocking.
    (record.request.type == "DOCUMENT" ?
       nonRequestTypes.includes(request.type) :
       record.request.type == request.type) &&

    // Matched element hiding filters don't relate to a particular request,
    // so we have to compare the selector in order to avoid duplicates.
    (record.filter && record.filter.selector) == (filter && filter.selector)
  );
}

function addRecord(panel, request, filter)
{
  if (!hasRecord(panel, request, filter))
  {
    panel.port.postMessage({
      type: "add-record",
      request,
      filter: getFilterInfo(filter)
    });

    panel.records.push({request, filter});
  }
}

function matchRequest(request)
{
  return defaultMatcher.matchesAny(
    request.url,
    RegExpFilter.typeMap[request.type],
    request.docDomain,
    request.thirdParty,
    request.sitekey,
    request.specificOnly
  );
}

/**
 * Logs a request to the devtools panel.
 *
 * @param {?Page}    page          The page the request occured on or null if
 *                                 the request isn't associated with a page
 * @param {string}   url           The URL of the request
 * @param {string}   type          The request type
 * @param {string}   docDomain     The IDN-decoded hostname of the document
 * @param {boolean}  thirdParty    Whether the origin of the request and
 *                                 document differs
 * @param {?string}  sitekey       The active sitekey if there is any
 * @param {?boolean} specificOnly  Whether generic filters should be ignored
 * @param {?BlockingFilter} filter The matched filter or null if there is no
 *                                 match
 */
exports.logRequest = function(page, url, type, docDomain,
                              thirdParty, sitekey,
                              specificOnly, filter)
{
  if (panels.size == 0)
    return;

  let request = {url, type, docDomain, thirdParty, sitekey, specificOnly};
  for (let [tabId, panel] of panels)
    if ((!page || page.id == tabId) && isActivePanel(panel))
      addRecord(panel, request, filter);
};

/**
 * Logs active element hiding filters to the devtools panel.
 *
 * @param {Page}     page       The page the elements were hidden on
 * @param {string[]} selectors  The selectors of applied ElemHideFilters
 * @param {string[]} filters    The text of applied ElemHideEmulationFilters
 * @param {string}   docDomain  The IDN-decoded hostname of the document
 */
function logHiddenElements(page, selectors, filters, docDomain)
{
  let panel = getActivePanel(page);
  if (panel)
  {
    for (let subscription of FilterStorage.subscriptions)
    {
      if (subscription.disabled)
        continue;

      for (let filter of subscription.filters)
      {
        // We only know the exact filter in case of element hiding emulation.
        // For regular element hiding filters, the content script only knows
        // the selector, so we have to find a filter that has an identical
        // selector and is active on the domain the match was reported from.
        let isActiveElemHideFilter = filter instanceof ElemHideFilter &&
                                     selectors.includes(filter.selector) &&
                                     filter.isActiveOnDomain(docDomain);

        if (isActiveElemHideFilter || filters.includes(filter.text))
          addRecord(panel, {type: "ELEMHIDE", docDomain}, filter);
      }
    }
  }
}

/**
 * Logs a whitelisting filter, that disables (some kind of)
 * blocking for a particular document, to the devtools panel.
 *
 * @param {Page}         page      The page the whitelisting is active on
 * @param {string}       url       The url of the whitelisted document
 * @param {number}       typeMask  The bit mask of whitelisting types checked
 *                                 for
 * @param {string}       docDomain The IDN-decoded hostname of the parent
 *                                 document
 * @param {WhitelistFilter} filter The matched whitelisting filter
 */
exports.logWhitelistedDocument = function(page, url, typeMask, docDomain,
                                          filter)
{
  let panel = getActivePanel(page);
  if (panel)
  {
    for (let type of nonRequestTypes)
    {
      if (typeMask & filter.contentType & RegExpFilter.typeMap[type])
        addRecord(panel, {url, type, docDomain}, filter);
    }
  }
};

/**
 * Checks whether a page is inspected by the devtools panel.
 *
 * @param {Page} page
 * @return {boolean}
 */
exports.hasPanel = function(page)
{
  return panels.has(page.id);
};

function onBeforeRequest(details)
{
  let panel = panels.get(details.tabId);

  // Clear the devtools panel and reload the inspected tab without caching
  // when a new request is issued. However, make sure that we don't end up
  // in an infinite recursion if we already triggered a reload.
  if (panel.reloading)
  {
    panel.reloading = false;
  }
  else
  {
    panel.records = [];
    panel.port.postMessage({type: "reset"});

    // We can't repeat the request if it isn't a GET request. Chrome would
    // prompt the user to confirm reloading the page, and POST requests are
    // known to cause issues on many websites if repeated.
    if (details.method == "GET")
      panel.reload = true;
  }
}

function onLoading(page)
{
  let tabId = page.id;
  let panel = panels.get(tabId);

  // Reloading the tab is the only way that allows bypassing all caches, in
  // order to see all requests in the devtools panel. Reloading must not be
  // performed before the tab changes to "loading", otherwise it will load the
  // previous URL.
  if (panel && panel.reload)
  {
    chrome.tabs.reload(tabId, {bypassCache: true});

    panel.reload = false;
    panel.reloading = true;
  }
}

function updateFilters(filters, added)
{
  for (let panel of panels.values())
  {
    for (let i = 0; i < panel.records.length; i++)
    {
      let record = panel.records[i];

      // If an added filter matches a request shown in the devtools panel,
      // update that record to show the new filter. Ignore filters that aren't
      // associated with any sub-resource request. There is no record for these
      // if they don't already match. In particular, in case of element hiding
      // filters, we also wouldn't know if any new element matches.
      if (added)
      {
        if (nonRequestTypes.includes(record.request.type))
          continue;

        let filter = matchRequest(record.request);
        if (!filters.includes(filter))
          continue;

        record.filter = filter;
      }

      // If a filter shown in the devtools panel got removed, update that
      // record to show the filter that matches now, or none, instead.
      // For filters that aren't associated with any sub-resource request,
      // just remove the record. We wouldn't know whether another filter
      // matches instead until the page is reloaded.
      else
      {
        if (!filters.includes(record.filter))
          continue;

        if (nonRequestTypes.includes(record.request.type))
        {
          panel.port.postMessage({
            type: "remove-record",
            index: i
          });
          panel.records.splice(i--, 1);
          continue;
        }

        record.filter = matchRequest(record.request);
      }

      panel.port.postMessage({
        type: "update-record",
        index: i,
        request: record.request,
        filter: getFilterInfo(record.filter)
      });
    }
  }
}

function onFilterAdded(filter)
{
  updateFilters([filter], true);
}

function onFilterRemoved(filter)
{
  updateFilters([filter], false);
}

function onSubscriptionAdded(subscription)
{
  if (subscription instanceof SpecialSubscription)
    updateFilters(subscription.filters, true);
}

chrome.runtime.onConnect.addListener(newPort =>
{
  let match = newPort.name.match(/^devtools-(\d+)$/);
  if (!match)
    return;

  let inspectedTabId = parseInt(match[1], 10);
  let localOnBeforeRequest = onBeforeRequest.bind();

  chrome.webRequest.onBeforeRequest.addListener(
    localOnBeforeRequest,
    {
      urls: ["http://*/*", "https://*/*"],
      types: ["main_frame"],
      tabId: inspectedTabId
    }
  );

  if (panels.size == 0)
  {
    ext.pages.onLoading.addListener(onLoading);
    FilterNotifier.on("filter.added", onFilterAdded);
    FilterNotifier.on("filter.removed", onFilterRemoved);
    FilterNotifier.on("subscription.added", onSubscriptionAdded);
  }

  newPort.onDisconnect.addListener(() =>
  {
    panels.delete(inspectedTabId);
    chrome.webRequest.onBeforeRequest.removeListener(localOnBeforeRequest);

    if (panels.size == 0)
    {
      ext.pages.onLoading.removeListener(onLoading);
      FilterNotifier.off("filter.added", onFilterAdded);
      FilterNotifier.off("filter.removed", onFilterRemoved);
      FilterNotifier.off("subscription.added", onSubscriptionAdded);
    }
  });

  panels.set(inspectedTabId, {port: newPort, records: []});
});

port.on("devtools.traceElemHide", (message, sender) =>
{
  logHiddenElements(
    sender.page, message.selectors, message.filters,
    extractHostFromFrame(sender.frame)
  );
});

return module.exports;
};

require.modules["popupBlocker"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module popupBlocker */

"use strict";

const {defaultMatcher} = require("matcher");
const {BlockingFilter, RegExpFilter} = require("filterClasses");
const {stringifyURL, isThirdParty, extractHostFromFrame} = require("url");
const {checkWhitelisted} = require("whitelisting");
const {logRequest} = require("devtools");

let loadingPopups = new Map();

function forgetPopup(tabId)
{
  loadingPopups.delete(tabId);

  if (loadingPopups.size == 0)
  {
    chrome.webRequest.onBeforeRequest.removeListener(onPopupURLChanged);
    chrome.webNavigation.onCommitted.removeListener(onPopupURLChanged);
    chrome.webNavigation.onCompleted.removeListener(onCompleted);
    chrome.tabs.onRemoved.removeListener(forgetPopup);
  }
}

function checkPotentialPopup(tabId, popup)
{
  let urlObj = new URL(popup.url || "about:blank");
  let urlString = stringifyURL(urlObj);
  let documentHost = extractHostFromFrame(popup.sourceFrame);
  let thirdParty = isThirdParty(urlObj, documentHost);

  let specificOnly = !!checkWhitelisted(
    popup.sourcePage, popup.sourceFrame,
    RegExpFilter.typeMap.GENERICBLOCK
  );

  let filter = defaultMatcher.matchesAny(
    urlString, RegExpFilter.typeMap.POPUP,
    documentHost, thirdParty, null, specificOnly
  );

  if (filter instanceof BlockingFilter)
    chrome.tabs.remove(tabId);

  logRequest(
    popup.sourcePage, urlString, "POPUP",
    documentHost, thirdParty, null,
    specificOnly, filter
  );
}

function onPopupURLChanged(details)
{
  // Ignore frames inside the popup window.
  if (details.frameId != 0)
    return;

  let popup = loadingPopups.get(details.tabId);
  if (popup)
  {
    popup.url = details.url;
    if (popup.sourceFrame)
      checkPotentialPopup(details.tabId, popup);
  }
}

function onCompleted(details)
{
  if (details.frameId == 0 && details.url != "about:blank")
    forgetPopup(details.tabId);
}

chrome.webNavigation.onCreatedNavigationTarget.addListener(details =>
{
  if (loadingPopups.size == 0)
  {
    chrome.webRequest.onBeforeRequest.addListener(
      onPopupURLChanged,
      {
        urls: ["http://*/*", "https://*/*"],
        types: ["main_frame"]
      }
    );
    chrome.webNavigation.onCommitted.addListener(onPopupURLChanged);
    chrome.webNavigation.onCompleted.addListener(onCompleted);
    chrome.tabs.onRemoved.addListener(forgetPopup);
  }

  let popup = {
    url: details.url,
    sourcePage: new ext.Page({id: details.sourceTabId}),
    sourceFrame: null
  };

  loadingPopups.set(details.tabId, popup);

  let frame = ext.getFrame(details.sourceTabId, details.sourceFrameId);

  if (checkWhitelisted(popup.sourcePage, frame))
  {
    forgetPopup(details.tabId);
  }
  else
  {
    popup.sourceFrame = frame;
    checkPotentialPopup(details.tabId, popup);
  }
});

return module.exports;
};

require.modules["uninstall"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/** @module uninstall */

"use strict";

const info = require("info");
const {Prefs} = require("prefs");
const {Utils} = require("utils");

function setUninstallURL()
{
  let search = [];
  for (let key of ["addonName", "addonVersion", "application",
                   "applicationVersion", "platform", "platformVersion"])
    search.push(key + "=" + encodeURIComponent(info[key]));

  let downlCount = Prefs.notificationdata.downloadCount || 0;

  if (downlCount > 4)
  {
    if (downlCount < 8)
      downlCount = "5-7";
    else if (downlCount < 30)
      downlCount = "8-29";
    else if (downlCount < 90)
      downlCount = "30-89";
    else if (downlCount < 180)
      downlCount = "90-179";
    else
      downlCount = "180+";
  }

  search.push("notificationDownloadCount=" + encodeURIComponent(downlCount));

  chrome.runtime.setUninstallURL(Utils.getDocLink("uninstalled") + "&" +
                                 search.join("&"));
}

// The uninstall URL contains the notification download count as a parameter,
// therefore we must wait for preferences to be loaded before generating the
// URL and we need to re-generate it each time the notification data changes.
if ("setUninstallURL" in chrome.runtime)
{
  Prefs.untilLoaded.then(setUninstallURL);
  Prefs.on("notificationdata", setUninstallURL);
}

return module.exports;
};

require.modules["csp"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

// The webRequest API doesn't support WebSocket connection blocking in Microsoft
// Edge and versions of Chrome before 58. Therefore for those we inject CSP
// headers below as a workaround. See https://crbug.com/129353 and
// https://developer.microsoft.com/en-us/microsoft-edge/platform/issues/10297376/
if (!chrome.webRequest.ResourceType ||
    !("WEBSOCKET" in chrome.webRequest.ResourceType))
{
  const {defaultMatcher} = require("matcher");
  const {BlockingFilter, RegExpFilter} = require("filterClasses");
  const {getDecodedHostname} = require("url");
  const {checkWhitelisted} = require("whitelisting");

  chrome.webRequest.onHeadersReceived.addListener(details =>
  {
    let hostname = getDecodedHostname(new URL(details.url));
    let match = defaultMatcher.matchesAny("", RegExpFilter.typeMap.WEBSOCKET,
                                          hostname, false, null, true);
    if (match instanceof BlockingFilter &&
        !checkWhitelisted(new ext.Page({id: details.tabId}),
                          ext.getFrame(details.tabId, details.frameId)))
    {
      details.responseHeaders.push({
        name: "Content-Security-Policy",
        // We're blocking WebSockets here by adding a connect-src restriction
        // since the Chrome extension API does not allow us to intercept them.
        // https://bugs.chromium.org/p/chromium/issues/detail?id=129353
        //
        // We also need the frame-src and object-src restrictions since CSPs
        // are not inherited from the parent for documents with data: and blob:
        // URLs, see https://crbug.com/513860.
        //
        // We must use the deprecated child-src directive instead of worker-src
        // since that's not supported yet (as of Chrome 56.)
        //
        // "http:" also includes "https:" implictly.
        // https://www.chromestatus.com/feature/6653486812889088
        value: "connect-src http:; child-src http:; " +
               "frame-src http:; object-src http:"
      });
      return {responseHeaders: details.responseHeaders};
    }
  }, {
    urls: ["http://*/*", "https://*/*"],
    // We must also intercept script requests since otherwise Web Workers can
    // be abused to execute scripts for which our Content Security Policy
    // won't be injected.
    // https://github.com/gorhill/uBO-Extra/issues/19
    types: ["main_frame", "sub_frame", "script"]
  }, ["blocking", "responseHeaders"]);
}

return module.exports;
};

require.modules["coreUtils"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

function desc(properties)
{
  let descriptor = {};
  let keys = Object.keys(properties);

  for (let key of keys)
    descriptor[key] = Object.getOwnPropertyDescriptor(properties, key);

  return descriptor;
}
exports.desc = desc;

function extend(cls, properties)
{
  return Object.create(cls.prototype, desc(properties));
}
exports.extend = extend;

return module.exports;
};

require.modules["common"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * Converts filter text into regular expression string
 * @param {string} text as in Filter()
 * @return {string} regular expression representation of filter text
 */
function filterToRegExp(text)
{
  return text
    // remove multiple wildcards
    .replace(/\*+/g, "*")
    // remove anchors following separator placeholder
    .replace(/\^\|$/, "^")
    // escape special symbols
    .replace(/\W/g, "\\$&")
    // replace wildcards by .*
    .replace(/\\\*/g, ".*")
    // process separator placeholders (all ANSI characters but alphanumeric
    // characters and _%.-)
    .replace(/\\\^/g, "(?:[\\x00-\\x24\\x26-\\x2C\\x2F\\x3A-\\x40\\x5B-\\x5E\\x60\\x7B-\\x7F]|$)")
    // process extended anchor at expression start
    .replace(/^\\\|\\\|/, "^[\\w\\-]+:\\/+(?!\\/)(?:[^\\/]+\\.)?")
    // process anchor at expression start
    .replace(/^\\\|/, "^")
    // process anchor at expression end
    .replace(/\\\|$/, "$")
    // remove leading wildcards
    .replace(/^(\.\*)/, "")
    // remove trailing wildcards
    .replace(/(\.\*)$/, "");
}

exports.filterToRegExp = filterToRegExp;

function splitSelector(selector)
{
  if (selector.indexOf(",") == -1)
    return [selector];

  let selectors = [];
  let start = 0;
  let level = 0;
  let sep = "";

  for (let i = 0; i < selector.length; i++)
  {
    let chr = selector[i];

    if (chr == "\\")        // ignore escaped characters
      i++;
    else if (chr == sep)    // don't split within quoted text
      sep = "";             // e.g. [attr=","]
    else if (sep == "")
    {
      if (chr == '"' || chr == "'")
        sep = chr;
      else if (chr == "(")  // don't split between parentheses
        level++;            // e.g. :matches(div,span)
      else if (chr == ")")
        level = Math.max(0, level - 1);
      else if (chr == "," && level == 0)
      {
        selectors.push(selector.substring(start, i));
        start = i + 1;
      }
    }
  }

  selectors.push(selector.substring(start));
  return selectors;
}

exports.splitSelector = splitSelector;

return module.exports;
};

require.modules["downloader"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview Downloads a set of URLs in regular time intervals.
 */

const {Utils} = require("utils");

const MILLIS_IN_SECOND = exports.MILLIS_IN_SECOND = 1000;
const MILLIS_IN_MINUTE = exports.MILLIS_IN_MINUTE = 60 * MILLIS_IN_SECOND;
const MILLIS_IN_HOUR = exports.MILLIS_IN_HOUR = 60 * MILLIS_IN_MINUTE;
const MILLIS_IN_DAY = exports.MILLIS_IN_DAY = 24 * MILLIS_IN_HOUR;

let Downloader =
/**
 * Creates a new downloader instance.
 * @param {Function} dataSource
 *   Function that will yield downloadable objects on each check
 * @param {number} initialDelay
 *   Number of milliseconds to wait before the first check
 * @param {number} checkInterval
 *   Interval between the checks
 * @constructor
 */
exports.Downloader = function(dataSource, initialDelay, checkInterval)
{
  this.dataSource = dataSource;
  this._timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
  this._timer.initWithCallback(() =>
  {
    this._timer.delay = checkInterval;
    this._doCheck();
  }, initialDelay, Ci.nsITimer.TYPE_REPEATING_SLACK);
  this._downloading = Object.create(null);
};
Downloader.prototype =
{
  /**
   * Timer triggering the downloads.
   * @type {nsITimer}
   */
  _timer: null,

  /**
   * Map containing the URLs of objects currently being downloaded as its keys.
   */
  _downloading: null,

  /**
   * Function that will yield downloadable objects on each check.
   * @type {Function}
   */
  dataSource: null,

  /**
   * Maximal time interval that the checks can be left out until the soft
   * expiration interval increases.
   * @type {number}
   */
  maxAbsenceInterval: 1 * MILLIS_IN_DAY,

  /**
   * Minimal time interval before retrying a download after an error.
   * @type {number}
   */
  minRetryInterval: 1 * MILLIS_IN_DAY,

  /**
   * Maximal allowed expiration interval, larger expiration intervals will be
   * corrected.
   * @type {number}
   */
  maxExpirationInterval: 14 * MILLIS_IN_DAY,

  /**
   * Maximal number of redirects before the download is considered as failed.
   * @type {number}
   */
  maxRedirects: 5,

  /**
   * Called whenever expiration intervals for an object need to be adapted.
   * @type {Function}
   */
  onExpirationChange: null,

  /**
   * Callback to be triggered whenever a download starts.
   * @type {Function}
   */
  onDownloadStarted: null,

  /**
   * Callback to be triggered whenever a download finishes successfully. The
   * callback can return an error code to indicate that the data is wrong.
   * @type {Function}
   */
  onDownloadSuccess: null,

  /**
   * Callback to be triggered whenever a download fails.
   * @type {Function}
   */
  onDownloadError: null,

  /**
   * Checks whether anything needs downloading.
   */
  _doCheck()
  {
    let now = Date.now();
    for (let downloadable of this.dataSource())
    {
      if (downloadable.lastCheck &&
          now - downloadable.lastCheck > this.maxAbsenceInterval)
      {
        // No checks for a long time interval - user must have been offline,
        // e.g.  during a weekend. Increase soft expiration to prevent load
        // peaks on the server.
        downloadable.softExpiration += now - downloadable.lastCheck;
      }
      downloadable.lastCheck = now;

      // Sanity check: do expiration times make sense? Make sure people changing
      // system clock don't get stuck with outdated subscriptions.
      if (downloadable.hardExpiration - now > this.maxExpirationInterval)
        downloadable.hardExpiration = now + this.maxExpirationInterval;
      if (downloadable.softExpiration - now > this.maxExpirationInterval)
        downloadable.softExpiration = now + this.maxExpirationInterval;

      // Notify the caller about changes to expiration parameters
      if (this.onExpirationChange)
        this.onExpirationChange(downloadable);

      // Does that object need downloading?
      if (downloadable.softExpiration > now &&
          downloadable.hardExpiration > now)
      {
        continue;
      }

      // Do not retry downloads too often
      if (downloadable.lastError &&
          now - downloadable.lastError < this.minRetryInterval)
      {
        continue;
      }

      this._download(downloadable, 0);
    }
  },

  /**
   * Stops the periodic checks.
   */
  cancel()
  {
    this._timer.cancel();
  },

  /**
   * Checks whether an address is currently being downloaded.
   * @param {string} url
   * @return {boolean}
   */
  isDownloading(url)
  {
    return url in this._downloading;
  },

  /**
   * Starts downloading for an object.
   * @param {Downloadable} downloadable
   */
  download(downloadable)
  {
    // Make sure to detach download from the current execution context
    Utils.runAsync(this._download.bind(this, downloadable, 0));
  },

  /**
   * Generates the real download URL for an object by appending various
   * parameters.
   * @param {Downloadable} downloadable
   * @return {string}
   */
  getDownloadUrl(downloadable)
  {
    const {addonName, addonVersion, application, applicationVersion,
           platform, platformVersion} = require("info");
    let url = downloadable.redirectURL || downloadable.url;
    if (url.indexOf("?") >= 0)
      url += "&";
    else
      url += "?";
    // We limit the download count to 4+ to keep the request anonymized
    let {downloadCount} = downloadable;
    if (downloadCount > 4)
      downloadCount = "4+";
    url += "addonName=" + encodeURIComponent(addonName) +
        "&addonVersion=" + encodeURIComponent(addonVersion) +
        "&application=" + encodeURIComponent(application) +
        "&applicationVersion=" + encodeURIComponent(applicationVersion) +
        "&platform=" + encodeURIComponent(platform) +
        "&platformVersion=" + encodeURIComponent(platformVersion) +
        "&lastVersion=" + encodeURIComponent(downloadable.lastVersion) +
        "&downloadCount=" + encodeURIComponent(downloadCount);
    return url;
  },

  _download(downloadable, redirects)
  {
    if (this.isDownloading(downloadable.url))
      return;

    let downloadUrl = this.getDownloadUrl(downloadable);
    let request = null;

    let errorCallback = function errorCallback(error)
    {
      let channelStatus = -1;
      try
      {
        channelStatus = request.channel.status;
      }
      catch (e) {}

      let responseStatus = request.status;

      Cu.reportError("Adblock Plus: Downloading URL " + downloadable.url +
                     " failed (" + error + ")\n" +
                     "Download address: " + downloadUrl + "\n" +
                     "Channel status: " + channelStatus + "\n" +
                     "Server response: " + responseStatus);

      if (this.onDownloadError)
      {
        // Allow one extra redirect if the error handler gives us a redirect URL
        let redirectCallback = null;
        if (redirects <= this.maxRedirects)
        {
          redirectCallback = url =>
          {
            downloadable.redirectURL = url;
            this._download(downloadable, redirects + 1);
          };
        }

        this.onDownloadError(downloadable, downloadUrl, error, channelStatus,
                             responseStatus, redirectCallback);
      }
    }.bind(this);

    try
    {
      request = new XMLHttpRequest();
      request.mozBackgroundRequest = true;
      request.open("GET", downloadUrl);
    }
    catch (e)
    {
      errorCallback("synchronize_invalid_url");
      return;
    }

    try
    {
      request.overrideMimeType("text/plain");
      request.channel.loadFlags = request.channel.loadFlags |
                                  request.channel.INHIBIT_CACHING |
                                  request.channel.VALIDATE_ALWAYS;

      // Override redirect limit from preferences, user might have set it to 1
      if (request.channel instanceof Ci.nsIHttpChannel)
        request.channel.redirectionLimit = this.maxRedirects;
    }
    catch (e)
    {
      Cu.reportError(e);
    }

    request.addEventListener("error", event =>
    {
      if (onShutdown.done)
        return;

      delete this._downloading[downloadable.url];
      errorCallback("synchronize_connection_error");
    }, false);

    request.addEventListener("load", event =>
    {
      if (onShutdown.done)
        return;

      delete this._downloading[downloadable.url];

      // Status will be 0 for non-HTTP requests
      if (request.status && request.status != 200)
      {
        errorCallback("synchronize_connection_error");
        return;
      }

      downloadable.downloadCount++;

      this.onDownloadSuccess(
        downloadable, request.responseText, errorCallback,
        url =>
        {
          if (redirects >= this.maxRedirects)
            errorCallback("synchronize_connection_error");
          else
          {
            downloadable.redirectURL = url;
            this._download(downloadable, redirects + 1);
          }
        }
      );
    });

    request.send(null);

    this._downloading[downloadable.url] = true;
    if (this.onDownloadStarted)
      this.onDownloadStarted(downloadable);
  },

  /**
   * Produces a soft and a hard expiration interval for a given supplied
   * expiration interval.
   * @param {number} interval
   * @return {Array} soft and hard expiration interval
   */
  processExpirationInterval(interval)
  {
    interval = Math.min(Math.max(interval, 0), this.maxExpirationInterval);
    let soft = Math.round(interval * (Math.random() * 0.4 + 0.8));
    let hard = interval * 2;
    let now = Date.now();
    return [now + soft, now + hard];
  }
};

/**
 * An object that can be downloaded by the downloadable
 * @param {string} url  URL that has to be requested for the object
 * @constructor
 */
let Downloadable = exports.Downloadable = function Downloadable(url)
{
  this.url = url;
};
Downloadable.prototype =
{
  /**
   * URL that has to be requested for the object.
   * @type {string}
   */
  url: null,

  /**
   * URL that the download was redirected to if any.
   * @type {string}
   */
  redirectURL: null,

  /**
   * Time of last download error or 0 if the last download was successful.
   * @type {number}
   */
  lastError: 0,

  /**
   * Time of last check whether the object needs downloading.
   * @type {number}
   */
  lastCheck: 0,

  /**
   * Object version corresponding to the last successful download.
   * @type {number}
   */
  lastVersion: 0,

  /**
   * Soft expiration interval, will increase if no checks are performed for a
   * while.
   * @type {number}
   */
  softExpiration: 0,

  /**
   * Hard expiration interval, this is fixed.
   * @type {number}
   */
  hardExpiration: 0,

  /**
   * Number indicating how often the object was downloaded.
   * @type {number}
   */
  downloadCount: 0
};

return module.exports;
};

require.modules["elemHide"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview Element hiding implementation.
 */

const {ElemHideException} = require("filterClasses");
const {FilterNotifier} = require("filterNotifier");

/**
 * Lookup table, filters by their associated key
 * @type {Object}
 */
let filterByKey = [];

/**
 * Lookup table, keys of the filters by filter text
 * @type {Object}
 */
let keyByFilter = Object.create(null);

/**
 * Nested lookup table, filter (or false if inactive) by filter key by domain.
 * (Only contains filters that aren't unconditionally matched for all domains.)
 * @type {Object}
 */
let filtersByDomain = Object.create(null);

/**
 * Lookup table, filter key by selector. (Only used for selectors that are
 * unconditionally matched for all domains.)
 */
let filterKeyBySelector = Object.create(null);

/**
 * This array caches the keys of filterKeyBySelector table (selectors which
 * unconditionally apply on all domains). It will be null if the cache needs to
 * be rebuilt.
 */
let unconditionalSelectors = null;

/**
 * This array caches the values of filterKeyBySelector table (filterIds for
 * selectors which unconditionally apply on all domains). It will be null if the
 * cache needs to be rebuilt.
 */
let unconditionalFilterKeys = null;

/**
 * Object to be used instead when a filter has a blank domains property.
 */
let defaultDomains = Object.create(null);
defaultDomains[""] = true;

/**
 * Lookup table, keys are known element hiding exceptions
 * @type {Object}
 */
let knownExceptions = Object.create(null);

/**
 * Lookup table, lists of element hiding exceptions by selector
 * @type {Object}
 */
let exceptions = Object.create(null);

/**
 * Container for element hiding filters
 * @class
 */
let ElemHide = exports.ElemHide = {
  /**
   * Removes all known filters
   */
  clear()
  {
    filterByKey = [];
    keyByFilter = Object.create(null);
    filtersByDomain = Object.create(null);
    filterKeyBySelector = Object.create(null);
    unconditionalSelectors = unconditionalFilterKeys = null;
    knownExceptions = Object.create(null);
    exceptions = Object.create(null);
    FilterNotifier.emit("elemhideupdate");
  },

  _addToFiltersByDomain(key, filter)
  {
    let domains = filter.domains || defaultDomains;
    for (let domain in domains)
    {
      let filters = filtersByDomain[domain];
      if (!filters)
        filters = filtersByDomain[domain] = Object.create(null);

      if (domains[domain])
        filters[key] = filter;
      else
        filters[key] = false;
    }
  },

  /**
   * Add a new element hiding filter
   * @param {ElemHideFilter} filter
   */
  add(filter)
  {
    if (filter instanceof ElemHideException)
    {
      if (filter.text in knownExceptions)
        return;

      let {selector} = filter;
      if (!(selector in exceptions))
        exceptions[selector] = [];
      exceptions[selector].push(filter);

      // If this is the first exception for a previously unconditionally
      // applied element hiding selector we need to take care to update the
      // lookups.
      let filterKey = filterKeyBySelector[selector];
      if (typeof filterKey != "undefined")
      {
        this._addToFiltersByDomain(filterKey, filterByKey[filterKey]);
        delete filterKeyBySelector[selector];
        unconditionalSelectors = unconditionalFilterKeys = null;
      }

      knownExceptions[filter.text] = true;
    }
    else
    {
      if (filter.text in keyByFilter)
        return;

      let key = filterByKey.push(filter) - 1;
      keyByFilter[filter.text] = key;

      if (!(filter.domains || filter.selector in exceptions))
      {
        // The new filter's selector is unconditionally applied to all domains
        filterKeyBySelector[filter.selector] = key;
        unconditionalSelectors = unconditionalFilterKeys = null;
      }
      else
      {
        // The new filter's selector only applies to some domains
        this._addToFiltersByDomain(key, filter);
      }
    }

    FilterNotifier.emit("elemhideupdate");
  },

  _removeFilterKey(key, filter)
  {
    if (filterKeyBySelector[filter.selector] == key)
    {
      delete filterKeyBySelector[filter.selector];
      unconditionalSelectors = unconditionalFilterKeys = null;
      return;
    }

    // We haven't found this filter in unconditional filters, look in
    // filtersByDomain.
    let domains = filter.domains || defaultDomains;
    for (let domain in domains)
    {
      let filters = filtersByDomain[domain];
      if (filters)
        delete filters[key];
    }
  },

  /**
   * Removes an element hiding filter
   * @param {ElemHideFilter} filter
   */
  remove(filter)
  {
    if (filter instanceof ElemHideException)
    {
      if (!(filter.text in knownExceptions))
        return;

      let list = exceptions[filter.selector];
      let index = list.indexOf(filter);
      if (index >= 0)
        list.splice(index, 1);
      delete knownExceptions[filter.text];
    }
    else
    {
      if (!(filter.text in keyByFilter))
        return;

      let key = keyByFilter[filter.text];
      delete filterByKey[key];
      delete keyByFilter[filter.text];
      this._removeFilterKey(key, filter);
    }

    FilterNotifier.emit("elemhideupdate");
  },

  /**
   * Checks whether an exception rule is registered for a filter on a particular
   * domain.
   * @param {Filter} filter
   * @param {string} docDomain
   * @return {ElemHideException}
   */
  getException(filter, docDomain)
  {
    if (!(filter.selector in exceptions))
      return null;

    let list = exceptions[filter.selector];
    for (let i = list.length - 1; i >= 0; i--)
    {
      if (list[i].isActiveOnDomain(docDomain))
        return list[i];
    }

    return null;
  },

  /**
   * Retrieves an element hiding filter by the corresponding protocol key
   * @param {number} key
   * @return {Filter}
   */
  getFilterByKey(key)
  {
    return (key in filterByKey ? filterByKey[key] : null);
  },

  /**
   * Returns a list of all selectors as a nested map. On first level, the keys
   * are all values of `ElemHideBase.selectorDomain` (domains on which these
   * selectors should apply, ignoring exceptions). The values are maps again,
   * with the keys being selectors and values the corresponding filter keys.
   * @returns {Map.<String,Map<String,String>>}
   */
  getSelectors()
  {
    let domains = new Map();
    for (let key in filterByKey)
    {
      let filter = filterByKey[key];
      if (!filter.selector)
        continue;

      let domain = filter.selectorDomain || "";

      if (!domains.has(domain))
        domains.set(domain, new Map());
      domains.get(domain).set(filter.selector, key);
    }

    return domains;
  },

  /**
   * Returns a list of selectors that apply on each website unconditionally.
   * @returns {string[]}
   */
  getUnconditionalSelectors()
  {
    if (!unconditionalSelectors)
      unconditionalSelectors = Object.keys(filterKeyBySelector);
    return unconditionalSelectors.slice();
  },

  /**
   * Returns a list of filter keys for selectors which apply to all websites
   * without exception.
   * @returns {number[]}
   */
  getUnconditionalFilterKeys()
  {
    if (!unconditionalFilterKeys)
    {
      let selectors = this.getUnconditionalSelectors();
      unconditionalFilterKeys = [];
      for (let selector of selectors)
        unconditionalFilterKeys.push(filterKeyBySelector[selector]);
    }
    return unconditionalFilterKeys.slice();
  },


  /**
   * Constant used by getSelectorsForDomain to return all selectors applying to
   * a particular hostname.
   */
  ALL_MATCHING: 0,

  /**
   * Constant used by getSelectorsForDomain to exclude selectors which apply to
   * all websites without exception.
   */
  NO_UNCONDITIONAL: 1,

  /**
   * Constant used by getSelectorsForDomain to return only selectors for filters
   * which specifically match the given host name.
   */
  SPECIFIC_ONLY: 2,

  /**
   * Determines from the current filter list which selectors should be applied
   * on a particular host name. Optionally returns the corresponding filter
   * keys.
   * @param {string} domain
   * @param {number} [criteria]
   *   One of the following: ElemHide.ALL_MATCHING, ElemHide.NO_UNCONDITIONAL or
   *                         ElemHide.SPECIFIC_ONLY.
   * @param {boolean} [provideFilterKeys]
   *   If true, the function will return a list of corresponding filter keys in
   *   addition to selectors.
   * @returns {string[]|Array.<string[]>}
   *   List of selectors or an array with two elements (list of selectors and
   *   list of corresponding keys) if provideFilterKeys is true.
   */
  getSelectorsForDomain(domain, criteria, provideFilterKeys)
  {
    let filterKeys = [];
    let selectors = [];

    if (typeof criteria == "undefined")
      criteria = ElemHide.ALL_MATCHING;
    if (criteria < ElemHide.NO_UNCONDITIONAL)
    {
      selectors = this.getUnconditionalSelectors();
      if (provideFilterKeys)
        filterKeys = this.getUnconditionalFilterKeys();
    }

    let specificOnly = (criteria >= ElemHide.SPECIFIC_ONLY);
    let seenFilters = Object.create(null);
    let currentDomain = domain ? domain.toUpperCase() : "";
    while (true)
    {
      if (specificOnly && currentDomain == "")
        break;

      let filters = filtersByDomain[currentDomain];
      if (filters)
      {
        for (let filterKey in filters)
        {
          if (filterKey in seenFilters)
            continue;
          seenFilters[filterKey] = true;

          let filter = filters[filterKey];
          if (filter && !this.getException(filter, domain))
          {
            selectors.push(filter.selector);
            // It is faster to always push the key, even if not required.
            filterKeys.push(filterKey);
          }
        }
      }

      if (currentDomain == "")
        break;

      let nextDot = currentDomain.indexOf(".");
      currentDomain = nextDot == -1 ? "" : currentDomain.substr(nextDot + 1);
    }

    if (provideFilterKeys)
      return [selectors, filterKeys];
    return selectors;
  }
};

return module.exports;
};

require.modules["elemHideEmulation"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview Element hiding emulation implementation.
 */

const {ElemHide} = require("elemHide");
const {Filter} = require("filterClasses");

let filters = Object.create(null);

/**
 * Container for element hiding emulation filters
 * @class
 */
let ElemHideEmulation = {
  /**
   * Removes all known filters
   */
  clear()
  {
    filters = Object.create(null);
  },

  /**
   * Add a new element hiding emulation filter
   * @param {ElemHideEmulationFilter} filter
   */
  add(filter)
  {
    filters[filter.text] = true;
  },

  /**
   * Removes an element hiding emulation filter
   * @param {ElemHideEmulationFilter} filter
   */
  remove(filter)
  {
    delete filters[filter.text];
  },

  /**
   * Returns a list of all rules active on a particular domain
   * @param {string} domain
   * @return {ElemHideEmulationFilter[]}
   */
  getRulesForDomain(domain)
  {
    let result = [];
    let keys = Object.getOwnPropertyNames(filters);
    for (let key of keys)
    {
      let filter = Filter.fromText(key);
      if (filter.isActiveOnDomain(domain) &&
          !ElemHide.getException(filter, domain))
      {
        result.push(filter);
      }
    }
    return result;
  }
};
exports.ElemHideEmulation = ElemHideEmulation;

return module.exports;
};

require.modules["events"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * Registers and emits named events.
 *
 * @constructor
 */
exports.EventEmitter = function()
{
  this._listeners = Object.create(null);
};

exports.EventEmitter.prototype = {
  /**
   * Adds a listener for the specified event name.
   *
   * @param {string}   name
   * @param {function} listener
   */
  on(name, listener)
  {
    if (name in this._listeners)
      this._listeners[name].push(listener);
    else
      this._listeners[name] = [listener];
  },

  /**
   * Removes a listener for the specified event name.
   *
   * @param {string}   name
   * @param {function} listener
   */
  off(name, listener)
  {
    let listeners = this._listeners[name];
    if (listeners)
    {
      let idx = listeners.indexOf(listener);
      if (idx != -1)
        listeners.splice(idx, 1);
    }
  },

  /**
   * Adds a one time listener and returns a promise that
   * is resolved the next time the specified event is emitted.
   * @param {string} name
   * @return {Promise}
   */
  once(name)
  {
    return new Promise(resolve =>
    {
      let listener = () =>
      {
        this.off(name, listener);
        resolve();
      };

      this.on(name, listener);
    });
  },

  /**
   * Returns a copy of the array of listeners for the specified event.
   *
   * @param {string} name
   * @return {function[]}
   */
  listeners(name)
  {
    let listeners = this._listeners[name];
    return listeners ? listeners.slice() : [];
  },

  /**
   * Calls all previously added listeners for the given event name.
   *
   * @param {string} name
   * @param {...*}   [arg]
   */
  emit(name, ...args)
  {
    let listeners = this.listeners(name);
    for (let listener of listeners)
      listener(...args);
  }
};

return module.exports;
};

require.modules["filterClasses"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview Definition of Filter class and its subclasses.
 */

const {FilterNotifier} = require("filterNotifier");
const {extend} = require("coreUtils");
const {filterToRegExp} = require("common");

/**
 * Abstract base class for filters
 *
 * @param {string} text   string representation of the filter
 * @constructor
 */
function Filter(text)
{
  this.text = text;
  this.subscriptions = [];
}
exports.Filter = Filter;

Filter.prototype =
{
  /**
   * String representation of the filter
   * @type {string}
   */
  text: null,

  /**
   * Filter subscriptions the filter belongs to
   * @type {Subscription[]}
   */
  subscriptions: null,

  /**
   * Filter type as a string, e.g. "blocking".
   * @type {string}
   */
  get type()
  {
    throw new Error("Please define filter type in the subclass");
  },

  /**
   * Serializes the filter to an array of strings for writing out on the disk.
   * @param {string[]} buffer  buffer to push the serialization results into
   */
  serialize(buffer)
  {
    buffer.push("[Filter]");
    buffer.push("text=" + this.text);
  },

  toString()
  {
    return this.text;
  }
};

/**
 * Cache for known filters, maps string representation to filter objects.
 * @type {Object}
 */
Filter.knownFilters = Object.create(null);

/**
 * Regular expression that element hiding filters should match
 * @type {RegExp}
 */
Filter.elemhideRegExp = /^([^/*|@"!]*?)#([@?])?#(.+)$/;
/**
 * Regular expression that RegExp filters specified as RegExps should match
 * @type {RegExp}
 */
Filter.regexpRegExp = /^(@@)?\/.*\/(?:\$~?[\w-]+(?:=[^,\s]+)?(?:,~?[\w-]+(?:=[^,\s]+)?)*)?$/;
/**
 * Regular expression that options on a RegExp filter should match
 * @type {RegExp}
 */
Filter.optionsRegExp = /\$(~?[\w-]+(?:=[^,\s]+)?(?:,~?[\w-]+(?:=[^,\s]+)?)*)$/;

/**
 * Creates a filter of correct type from its text representation - does the
 * basic parsing and calls the right constructor then.
 *
 * @param {string} text   as in Filter()
 * @return {Filter}
 */
Filter.fromText = function(text)
{
  if (text in Filter.knownFilters)
    return Filter.knownFilters[text];

  let ret;
  let match = (text.includes("#") ? Filter.elemhideRegExp.exec(text) : null);
  if (match)
  {
    let propsMatch;
    if (!match[2] &&
        (propsMatch = /\[-abp-properties=(["'])([^"']+)\1\]/.exec(match[3])))
    {
      // This is legacy CSS properties syntax, convert to current syntax
      let prefix = match[3].substr(0, propsMatch.index);
      let expression = propsMatch[2];
      let suffix = match[3].substr(propsMatch.index + propsMatch[0].length);
      return Filter.fromText(`${match[1]}#?#` +
          `${prefix}:-abp-properties(${expression})${suffix}`);
    }

    ret = ElemHideBase.fromText(
      text, match[1], match[2], match[3]
    );
  }
  else if (text[0] == "!")
    ret = new CommentFilter(text);
  else
    ret = RegExpFilter.fromText(text);

  Filter.knownFilters[ret.text] = ret;
  return ret;
};

/**
 * Deserializes a filter
 *
 * @param {Object}  obj map of serialized properties and their values
 * @return {Filter} filter or null if the filter couldn't be created
 */
Filter.fromObject = function(obj)
{
  let ret = Filter.fromText(obj.text);
  if (ret instanceof ActiveFilter)
  {
    if ("disabled" in obj)
      ret._disabled = (obj.disabled == "true");
    if ("hitCount" in obj)
      ret._hitCount = parseInt(obj.hitCount, 10) || 0;
    if ("lastHit" in obj)
      ret._lastHit = parseInt(obj.lastHit, 10) || 0;
  }
  return ret;
};

/**
 * Removes unnecessary whitespaces from filter text, will only return null if
 * the input parameter is null.
 * @param {string} text
 * @return {string}
 */
Filter.normalize = function(text)
{
  if (!text)
    return text;

  // Remove line breaks and such
  text = text.replace(/[^\S ]/g, "");

  if (/^\s*!/.test(text))
  {
    // Don't remove spaces inside comments
    return text.trim();
  }
  else if (Filter.elemhideRegExp.test(text))
  {
    // Special treatment for element hiding filters, right side is allowed to
    // contain spaces
    let [, domain, separator, selector] = /^(.*?)(#@?#?)(.*)$/.exec(text);
    return domain.replace(/\s/g, "") + separator + selector.trim();
  }
  return text.replace(/\s/g, "");
};

/**
 * @see filterToRegExp
 */
Filter.toRegExp = filterToRegExp;

/**
 * Class for invalid filters
 * @param {string} text see Filter()
 * @param {string} reason Reason why this filter is invalid
 * @constructor
 * @augments Filter
 */
function InvalidFilter(text, reason)
{
  Filter.call(this, text);

  this.reason = reason;
}
exports.InvalidFilter = InvalidFilter;

InvalidFilter.prototype = extend(Filter, {
  type: "invalid",

  /**
   * Reason why this filter is invalid
   * @type {string}
   */
  reason: null,

  /**
   * See Filter.serialize()
   * @inheritdoc
   */
  serialize(buffer) {}
});

/**
 * Class for comments
 * @param {string} text see Filter()
 * @constructor
 * @augments Filter
 */
function CommentFilter(text)
{
  Filter.call(this, text);
}
exports.CommentFilter = CommentFilter;

CommentFilter.prototype = extend(Filter, {
  type: "comment",

  /**
   * See Filter.serialize()
   * @inheritdoc
   */
  serialize(buffer) {}
});

/**
 * Abstract base class for filters that can get hits
 * @param {string} text
 *   see Filter()
 * @param {string} [domains]
 *   Domains that the filter is restricted to separated by domainSeparator
 *   e.g. "foo.com|bar.com|~baz.com"
 * @constructor
 * @augments Filter
 */
function ActiveFilter(text, domains)
{
  Filter.call(this, text);

  this.domainSource = domains;
}
exports.ActiveFilter = ActiveFilter;

ActiveFilter.prototype = extend(Filter, {
  _disabled: false,
  _hitCount: 0,
  _lastHit: 0,

  /**
   * Defines whether the filter is disabled
   * @type {boolean}
   */
  get disabled()
  {
    return this._disabled;
  },
  set disabled(value)
  {
    if (value != this._disabled)
    {
      let oldValue = this._disabled;
      this._disabled = value;
      FilterNotifier.triggerListeners("filter.disabled", this, value, oldValue);
    }
    return this._disabled;
  },

  /**
   * Number of hits on the filter since the last reset
   * @type {number}
   */
  get hitCount()
  {
    return this._hitCount;
  },
  set hitCount(value)
  {
    if (value != this._hitCount)
    {
      let oldValue = this._hitCount;
      this._hitCount = value;
      FilterNotifier.triggerListeners("filter.hitCount", this, value, oldValue);
    }
    return this._hitCount;
  },

  /**
   * Last time the filter had a hit (in milliseconds since the beginning of the
   * epoch)
   * @type {number}
   */
  get lastHit()
  {
    return this._lastHit;
  },
  set lastHit(value)
  {
    if (value != this._lastHit)
    {
      let oldValue = this._lastHit;
      this._lastHit = value;
      FilterNotifier.triggerListeners("filter.lastHit", this, value, oldValue);
    }
    return this._lastHit;
  },

  /**
   * String that the domains property should be generated from
   * @type {string}
   */
  domainSource: null,

  /**
   * Separator character used in domainSource property, must be
   * overridden by subclasses
   * @type {string}
   */
  domainSeparator: null,

  /**
   * Determines whether the trailing dot in domain names isn't important and
   * should be ignored, must be overridden by subclasses.
   * @type {boolean}
   */
  ignoreTrailingDot: true,

  /**
   * Determines whether domainSource is already upper-case,
   * can be overridden by subclasses.
   * @type {boolean}
   */
  domainSourceIsUpperCase: false,

  /**
   * Map containing domains that this filter should match on/not match
   * on or null if the filter should match on all domains
   * @type {Object}
   */
  get domains()
  {
    // Despite this property being cached, the getter is called
    // several times on Safari, due to WebKit bug 132872
    let prop = Object.getOwnPropertyDescriptor(this, "domains");
    if (prop)
      return prop.value;

    let domains = null;

    if (this.domainSource)
    {
      let source = this.domainSource;
      if (!this.domainSourceIsUpperCase)
      {
        // RegExpFilter already have uppercase domains
        source = source.toUpperCase();
      }
      let list = source.split(this.domainSeparator);
      if (list.length == 1 && list[0][0] != "~")
      {
        // Fast track for the common one-domain scenario
        domains = Object.create(null);
        domains[""] = false;
        if (this.ignoreTrailingDot)
          list[0] = list[0].replace(/\.+$/, "");
        domains[list[0]] = true;
      }
      else
      {
        let hasIncludes = false;
        for (let i = 0; i < list.length; i++)
        {
          let domain = list[i];
          if (this.ignoreTrailingDot)
            domain = domain.replace(/\.+$/, "");
          if (domain == "")
            continue;

          let include;
          if (domain[0] == "~")
          {
            include = false;
            domain = domain.substr(1);
          }
          else
          {
            include = true;
            hasIncludes = true;
          }

          if (!domains)
            domains = Object.create(null);

          domains[domain] = include;
        }
        if (domains)
          domains[""] = !hasIncludes;
      }

      this.domainSource = null;
    }

    Object.defineProperty(this, "domains", {value: domains, enumerable: true});
    return this.domains;
  },

  /**
   * Array containing public keys of websites that this filter should apply to
   * @type {string[]}
   */
  sitekeys: null,

  /**
   * Checks whether this filter is active on a domain.
   * @param {string} docDomain domain name of the document that loads the URL
   * @param {string} [sitekey] public key provided by the document
   * @return {boolean} true in case of the filter being active
   */
  isActiveOnDomain(docDomain, sitekey)
  {
    // Sitekeys are case-sensitive so we shouldn't convert them to
    // upper-case to avoid false positives here. Instead we need to
    // change the way filter options are parsed.
    if (this.sitekeys &&
        (!sitekey || this.sitekeys.indexOf(sitekey.toUpperCase()) < 0))
    {
      return false;
    }

    // If no domains are set the rule matches everywhere
    if (!this.domains)
      return true;

    // If the document has no host name, match only if the filter
    // isn't restricted to specific domains
    if (!docDomain)
      return this.domains[""];

    if (this.ignoreTrailingDot)
      docDomain = docDomain.replace(/\.+$/, "");
    docDomain = docDomain.toUpperCase();

    while (true)
    {
      if (docDomain in this.domains)
        return this.domains[docDomain];

      let nextDot = docDomain.indexOf(".");
      if (nextDot < 0)
        break;
      docDomain = docDomain.substr(nextDot + 1);
    }
    return this.domains[""];
  },

  /**
   * Checks whether this filter is active only on a domain and its subdomains.
   * @param {string} docDomain
   * @return {boolean}
   */
  isActiveOnlyOnDomain(docDomain)
  {
    if (!docDomain || !this.domains || this.domains[""])
      return false;

    if (this.ignoreTrailingDot)
      docDomain = docDomain.replace(/\.+$/, "");
    docDomain = docDomain.toUpperCase();

    for (let domain in this.domains)
    {
      if (this.domains[domain] && domain != docDomain)
      {
        if (domain.length <= docDomain.length)
          return false;

        if (!domain.endsWith("." + docDomain))
          return false;
      }
    }

    return true;
  },

  /**
   * Checks whether this filter is generic or specific
   * @return {boolean}
   */
  isGeneric()
  {
    return !(this.sitekeys && this.sitekeys.length) &&
            (!this.domains || this.domains[""]);
  },

  /**
   * See Filter.serialize()
   * @inheritdoc
   */
  serialize(buffer)
  {
    if (this._disabled || this._hitCount || this._lastHit)
    {
      Filter.prototype.serialize.call(this, buffer);
      if (this._disabled)
        buffer.push("disabled=true");
      if (this._hitCount)
        buffer.push("hitCount=" + this._hitCount);
      if (this._lastHit)
        buffer.push("lastHit=" + this._lastHit);
    }
  }
});

/**
 * Abstract base class for RegExp-based filters
 * @param {string} text see Filter()
 * @param {string} regexpSource
 *   filter part that the regular expression should be build from
 * @param {number} [contentType]
 *   Content types the filter applies to, combination of values from
 *   RegExpFilter.typeMap
 * @param {boolean} [matchCase]
 *   Defines whether the filter should distinguish between lower and upper case
 *   letters
 * @param {string} [domains]
 *   Domains that the filter is restricted to, e.g. "foo.com|bar.com|~baz.com"
 * @param {boolean} [thirdParty]
 *   Defines whether the filter should apply to third-party or first-party
 *   content only
 * @param {string} [sitekeys]
 *   Public keys of websites that this filter should apply to
 * @constructor
 * @augments ActiveFilter
 */
function RegExpFilter(text, regexpSource, contentType, matchCase, domains,
                      thirdParty, sitekeys)
{
  ActiveFilter.call(this, text, domains, sitekeys);

  if (contentType != null)
    this.contentType = contentType;
  if (matchCase)
    this.matchCase = matchCase;
  if (thirdParty != null)
    this.thirdParty = thirdParty;
  if (sitekeys != null)
    this.sitekeySource = sitekeys;

  if (regexpSource.length >= 2 &&
      regexpSource[0] == "/" &&
      regexpSource[regexpSource.length - 1] == "/")
  {
    // The filter is a regular expression - convert it immediately to
    // catch syntax errors
    let regexp = new RegExp(regexpSource.substr(1, regexpSource.length - 2),
                            this.matchCase ? "" : "i");
    Object.defineProperty(this, "regexp", {value: regexp});
  }
  else
  {
    // No need to convert this filter to regular expression yet, do it on demand
    this.regexpSource = regexpSource;
  }
}
exports.RegExpFilter = RegExpFilter;

RegExpFilter.prototype = extend(ActiveFilter, {
  /**
   * @see ActiveFilter.domainSourceIsUpperCase
   */
  domainSourceIsUpperCase: true,

  /**
   * Number of filters contained, will always be 1 (required to
   * optimize Matcher).
   * @type {number}
   */
  length: 1,

  /**
   * @see ActiveFilter.domainSeparator
   */
  domainSeparator: "|",

  /**
   * Expression from which a regular expression should be generated -
   * for delayed creation of the regexp property
   * @type {string}
   */
  regexpSource: null,
  /**
   * Regular expression to be used when testing against this filter
   * @type {RegExp}
   */
  get regexp()
  {
    // Despite this property being cached, the getter is called
    // several times on Safari, due to WebKit bug 132872
    let prop = Object.getOwnPropertyDescriptor(this, "regexp");
    if (prop)
      return prop.value;

    let source = Filter.toRegExp(this.regexpSource);
    let regexp = new RegExp(source, this.matchCase ? "" : "i");
    Object.defineProperty(this, "regexp", {value: regexp});
    return regexp;
  },
  /**
   * Content types the filter applies to, combination of values from
   * RegExpFilter.typeMap
   * @type {number}
   */
  contentType: 0x7FFFFFFF,
  /**
   * Defines whether the filter should distinguish between lower and
   * upper case letters
   * @type {boolean}
   */
  matchCase: false,
  /**
   * Defines whether the filter should apply to third-party or
   * first-party content only. Can be null (apply to all content).
   * @type {boolean}
   */
  thirdParty: null,

  /**
   * String that the sitekey property should be generated from
   * @type {string}
   */
  sitekeySource: null,

  /**
   * Array containing public keys of websites that this filter should apply to
   * @type {string[]}
   */
  get sitekeys()
  {
    // Despite this property being cached, the getter is called
    // several times on Safari, due to WebKit bug 132872
    let prop = Object.getOwnPropertyDescriptor(this, "sitekeys");
    if (prop)
      return prop.value;

    let sitekeys = null;

    if (this.sitekeySource)
    {
      sitekeys = this.sitekeySource.split("|");
      this.sitekeySource = null;
    }

    Object.defineProperty(
      this, "sitekeys", {value: sitekeys, enumerable: true}
    );
    return this.sitekeys;
  },

  /**
   * Tests whether the URL matches this filter
   * @param {string} location URL to be tested
   * @param {number} typeMask bitmask of content / request types to match
   * @param {string} docDomain domain name of the document that loads the URL
   * @param {boolean} thirdParty should be true if the URL is a third-party
   *                             request
   * @param {string} sitekey public key provided by the document
   * @return {boolean} true in case of a match
   */
  matches(location, typeMask, docDomain, thirdParty, sitekey)
  {
    if (this.contentType & typeMask &&
        (this.thirdParty == null || this.thirdParty == thirdParty) &&
        this.isActiveOnDomain(docDomain, sitekey) && this.regexp.test(location))
    {
      return true;
    }
    return false;
  }
});

// Required to optimize Matcher, see also RegExpFilter.prototype.length
Object.defineProperty(RegExpFilter.prototype, "0", {
  get() { return this; }
});

/**
 * Creates a RegExp filter from its text representation
 * @param {string} text   same as in Filter()
 * @return {Filter}
 */
RegExpFilter.fromText = function(text)
{
  let blocking = true;
  let origText = text;
  if (text.indexOf("@@") == 0)
  {
    blocking = false;
    text = text.substr(2);
  }

  let contentType = null;
  let matchCase = null;
  let domains = null;
  let sitekeys = null;
  let thirdParty = null;
  let collapse = null;
  let options;
  let match = (text.indexOf("$") >= 0 ? Filter.optionsRegExp.exec(text) : null);
  if (match)
  {
    options = match[1].toUpperCase().split(",");
    text = match.input.substr(0, match.index);
    for (let option of options)
    {
      let value = null;
      let separatorIndex = option.indexOf("=");
      if (separatorIndex >= 0)
      {
        value = option.substr(separatorIndex + 1);
        option = option.substr(0, separatorIndex);
      }
      option = option.replace(/-/, "_");
      if (option in RegExpFilter.typeMap)
      {
        if (contentType == null)
          contentType = 0;
        contentType |= RegExpFilter.typeMap[option];
      }
      else if (option[0] == "~" && option.substr(1) in RegExpFilter.typeMap)
      {
        if (contentType == null)
          ({contentType} = RegExpFilter.prototype);
        contentType &= ~RegExpFilter.typeMap[option.substr(1)];
      }
      else if (option == "MATCH_CASE")
        matchCase = true;
      else if (option == "~MATCH_CASE")
        matchCase = false;
      else if (option == "DOMAIN" && typeof value != "undefined")
        domains = value;
      else if (option == "THIRD_PARTY")
        thirdParty = true;
      else if (option == "~THIRD_PARTY")
        thirdParty = false;
      else if (option == "COLLAPSE")
        collapse = true;
      else if (option == "~COLLAPSE")
        collapse = false;
      else if (option == "SITEKEY" && typeof value != "undefined")
        sitekeys = value;
      else
        return new InvalidFilter(origText, "filter_unknown_option");
    }
  }

  try
  {
    if (blocking)
    {
      return new BlockingFilter(origText, text, contentType, matchCase, domains,
                                thirdParty, sitekeys, collapse);
    }
    return new WhitelistFilter(origText, text, contentType, matchCase, domains,
                               thirdParty, sitekeys);
  }
  catch (e)
  {
    return new InvalidFilter(origText, "filter_invalid_regexp");
  }
};

/**
 * Maps type strings like "SCRIPT" or "OBJECT" to bit masks
 */
RegExpFilter.typeMap = {
  OTHER: 1,
  SCRIPT: 2,
  IMAGE: 4,
  STYLESHEET: 8,
  OBJECT: 16,
  SUBDOCUMENT: 32,
  DOCUMENT: 64,
  WEBSOCKET: 128,
  WEBRTC: 256,
  XBL: 1,
  PING: 1024,
  XMLHTTPREQUEST: 2048,
  OBJECT_SUBREQUEST: 4096,
  DTD: 1,
  MEDIA: 16384,
  FONT: 32768,

  BACKGROUND: 4,    // Backwards compat, same as IMAGE

  POPUP: 0x10000000,
  GENERICBLOCK: 0x20000000,
  ELEMHIDE: 0x40000000,
  GENERICHIDE: 0x80000000
};

// DOCUMENT, ELEMHIDE, POPUP, GENERICHIDE and GENERICBLOCK options shouldn't
// be there by default
RegExpFilter.prototype.contentType &= ~(RegExpFilter.typeMap.DOCUMENT |
                                        RegExpFilter.typeMap.ELEMHIDE |
                                        RegExpFilter.typeMap.POPUP |
                                        RegExpFilter.typeMap.GENERICHIDE |
                                        RegExpFilter.typeMap.GENERICBLOCK);

/**
 * Class for blocking filters
 * @param {string} text see Filter()
 * @param {string} regexpSource see RegExpFilter()
 * @param {number} contentType see RegExpFilter()
 * @param {boolean} matchCase see RegExpFilter()
 * @param {string} domains see RegExpFilter()
 * @param {boolean} thirdParty see RegExpFilter()
 * @param {string} sitekeys see RegExpFilter()
 * @param {boolean} collapse
 *   defines whether the filter should collapse blocked content, can be null
 * @constructor
 * @augments RegExpFilter
 */
function BlockingFilter(text, regexpSource, contentType, matchCase, domains,
                        thirdParty, sitekeys, collapse)
{
  RegExpFilter.call(this, text, regexpSource, contentType, matchCase, domains,
                    thirdParty, sitekeys);

  this.collapse = collapse;
}
exports.BlockingFilter = BlockingFilter;

BlockingFilter.prototype = extend(RegExpFilter, {
  type: "blocking",

  /**
   * Defines whether the filter should collapse blocked content.
   * Can be null (use the global preference).
   * @type {boolean}
   */
  collapse: null
});

/**
 * Class for whitelist filters
 * @param {string} text see Filter()
 * @param {string} regexpSource see RegExpFilter()
 * @param {number} contentType see RegExpFilter()
 * @param {boolean} matchCase see RegExpFilter()
 * @param {string} domains see RegExpFilter()
 * @param {boolean} thirdParty see RegExpFilter()
 * @param {string} sitekeys see RegExpFilter()
 * @constructor
 * @augments RegExpFilter
 */
function WhitelistFilter(text, regexpSource, contentType, matchCase, domains,
                         thirdParty, sitekeys)
{
  RegExpFilter.call(this, text, regexpSource, contentType, matchCase, domains,
                    thirdParty, sitekeys);
}
exports.WhitelistFilter = WhitelistFilter;

WhitelistFilter.prototype = extend(RegExpFilter, {
  type: "whitelist"
});

/**
 * Base class for element hiding filters
 * @param {string} text see Filter()
 * @param {string} [domains] Host names or domains the filter should be
 *                           restricted to
 * @param {string} selector   CSS selector for the HTML elements that should be
 *                            hidden
 * @constructor
 * @augments ActiveFilter
 */
function ElemHideBase(text, domains, selector)
{
  ActiveFilter.call(this, text, domains || null);

  if (domains)
  {
    this.selectorDomain = domains.replace(/,~[^,]+/g, "")
                                 .replace(/^~[^,]+,?/, "").toLowerCase();
  }

  // Braces are being escaped to prevent CSS rule injection.
  this.selector = selector.replace("{", "\\x7B ").replace("}", "\\x7D ");
}
exports.ElemHideBase = ElemHideBase;

ElemHideBase.prototype = extend(ActiveFilter, {
  /**
   * @see ActiveFilter.domainSeparator
   */
  domainSeparator: ",",

  /**
   * @see ActiveFilter.ignoreTrailingDot
   */
  ignoreTrailingDot: false,

  /**
   * Host name or domain the filter should be restricted to (can be null for
   * no restriction)
   * @type {string}
   */
  selectorDomain: null,
  /**
   * CSS selector for the HTML elements that should be hidden
   * @type {string}
   */
  selector: null
});

/**
 * Creates an element hiding filter from a pre-parsed text representation
 *
 * @param {string} text         same as in Filter()
 * @param {string?} domain
 *   domain part of the text representation
 * @param {string?} type
*    rule type, either empty or @ (exception) or ? (emulation rule)
 * @param {string} selector     raw CSS selector
 * @return {ElemHideFilter|ElemHideException|
 *          ElemHideEmulationFilter|InvalidFilter}
 */
ElemHideBase.fromText = function(text, domain, type, selector)
{
  // We don't allow ElemHide filters which have any empty domains.
  // Note: The ElemHide.prototype.domainSeparator is duplicated here, if that
  // changes this must be changed too.
  if (domain && /(^|,)~?(,|$)/.test(domain))
    return new InvalidFilter(text, "filter_invalid_domain");

  if (type == "@")
    return new ElemHideException(text, domain, selector);

  if (type == "?")
  {
    // Element hiding emulation filters are inefficient so we need to make sure
    // that they're only applied if they specify active domains
    if (!/,[^~][^,.]*\.[^,]/.test("," + domain))
      return new InvalidFilter(text, "filter_elemhideemulation_nodomain");

    return new ElemHideEmulationFilter(text, domain, selector);
  }

  return new ElemHideFilter(text, domain, selector);
};

/**
 * Class for element hiding filters
 * @param {string} text see Filter()
 * @param {string} domains  see ElemHideBase()
 * @param {string} selector see ElemHideBase()
 * @constructor
 * @augments ElemHideBase
 */
function ElemHideFilter(text, domains, selector)
{
  ElemHideBase.call(this, text, domains, selector);
}
exports.ElemHideFilter = ElemHideFilter;

ElemHideFilter.prototype = extend(ElemHideBase, {
  type: "elemhide"
});

/**
 * Class for element hiding exceptions
 * @param {string} text see Filter()
 * @param {string} domains  see ElemHideBase()
 * @param {string} selector see ElemHideBase()
 * @constructor
 * @augments ElemHideBase
 */
function ElemHideException(text, domains, selector)
{
  ElemHideBase.call(this, text, domains, selector);
}
exports.ElemHideException = ElemHideException;

ElemHideException.prototype = extend(ElemHideBase, {
  type: "elemhideexception"
});

/**
 * Class for element hiding emulation filters
 * @param {string} text           see Filter()
 * @param {string} domains        see ElemHideBase()
 * @param {string} selector       see ElemHideBase()
 * @constructor
 * @augments ElemHideBase
 */
function ElemHideEmulationFilter(text, domains, selector)
{
  ElemHideBase.call(this, text, domains, selector);
}
exports.ElemHideEmulationFilter = ElemHideEmulationFilter;

ElemHideEmulationFilter.prototype = extend(ElemHideBase, {
  type: "elemhideemulation"
});

return module.exports;
};

require.modules["filterListener"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview Component synchronizing filter storage with Matcher
 *               instances and ElemHide.
 */

const {Services} = Cu.import("resource://gre/modules/Services.jsm", {});
const {XPCOMUtils} = Cu.import("resource://gre/modules/XPCOMUtils.jsm", {});

const {FilterStorage} = require("filterStorage");
const {FilterNotifier} = require("filterNotifier");
const {ElemHide} = require("elemHide");
const {ElemHideEmulation} = require("elemHideEmulation");
const {defaultMatcher} = require("matcher");
const {ActiveFilter, RegExpFilter,
       ElemHideBase, ElemHideEmulationFilter} = require("filterClasses");
const {Prefs} = require("prefs");

/**
 * Increases on filter changes, filters will be saved if it exceeds 1.
 * @type {number}
 */
let isDirty = 0;

/**
 * This object can be used to change properties of the filter change listeners.
 * @class
 */
let FilterListener = {
  /**
   * Increases "dirty factor" of the filters and calls
   * FilterStorage.saveToDisk() if it becomes 1 or more. Save is
   * executed delayed to prevent multiple subsequent calls. If the
   * parameter is 0 it forces saving filters if any changes were
   * recorded after the previous save.
   * @param {number} factor
   */
  setDirty(factor)
  {
    if (factor == 0 && isDirty > 0)
      isDirty = 1;
    else
      isDirty += factor;
    if (isDirty >= 1)
    {
      isDirty = 0;
      FilterStorage.saveToDisk();
    }
  }
};

/**
 * Observer listening to history purge actions.
 * @class
 */
let HistoryPurgeObserver = {
  observe(subject, topic, data)
  {
    if (topic == "browser:purge-session-history" &&
        Prefs.clearStatsOnHistoryPurge)
    {
      FilterStorage.resetHitCounts();
      FilterListener.setDirty(0); // Force saving to disk

      Prefs.recentReports = [];
    }
  },
  QueryInterface: XPCOMUtils.generateQI(
    [Ci.nsISupportsWeakReference, Ci.nsIObserver]
  )
};

/**
 * Initializes filter listener on startup, registers the necessary hooks.
 */
function init()
{
  FilterNotifier.on("filter.hitCount", onFilterHitCount);
  FilterNotifier.on("filter.lastHit", onFilterLastHit);
  FilterNotifier.on("filter.added", onFilterAdded);
  FilterNotifier.on("filter.removed", onFilterRemoved);
  FilterNotifier.on("filter.disabled", onFilterDisabled);
  FilterNotifier.on("filter.moved", onGenericChange);

  FilterNotifier.on("subscription.added", onSubscriptionAdded);
  FilterNotifier.on("subscription.removed", onSubscriptionRemoved);
  FilterNotifier.on("subscription.disabled", onSubscriptionDisabled);
  FilterNotifier.on("subscription.updated", onSubscriptionUpdated);
  FilterNotifier.on("subscription.moved", onGenericChange);
  FilterNotifier.on("subscription.title", onGenericChange);
  FilterNotifier.on("subscription.fixedTitle", onGenericChange);
  FilterNotifier.on("subscription.homepage", onGenericChange);
  FilterNotifier.on("subscription.downloadStatus", onGenericChange);
  FilterNotifier.on("subscription.lastCheck", onGenericChange);
  FilterNotifier.on("subscription.errors", onGenericChange);

  FilterNotifier.on("load", onLoad);
  FilterNotifier.on("save", onSave);

  FilterStorage.loadFromDisk();

  Services.obs.addObserver(HistoryPurgeObserver,
                           "browser:purge-session-history", true);
  onShutdown.add(() =>
  {
    Services.obs.removeObserver(HistoryPurgeObserver,
                                "browser:purge-session-history");
  });
}
init();

/**
 * Notifies Matcher instances or ElemHide object about a new filter
 * if necessary.
 * @param {Filter} filter filter that has been added
 */
function addFilter(filter)
{
  if (!(filter instanceof ActiveFilter) || filter.disabled)
    return;

  let hasEnabled = false;
  for (let i = 0; i < filter.subscriptions.length; i++)
  {
    if (!filter.subscriptions[i].disabled)
      hasEnabled = true;
  }
  if (!hasEnabled)
    return;

  if (filter instanceof RegExpFilter)
    defaultMatcher.add(filter);
  else if (filter instanceof ElemHideBase)
  {
    if (filter instanceof ElemHideEmulationFilter)
      ElemHideEmulation.add(filter);
    else
      ElemHide.add(filter);
  }
}

/**
 * Notifies Matcher instances or ElemHide object about removal of a filter
 * if necessary.
 * @param {Filter} filter filter that has been removed
 */
function removeFilter(filter)
{
  if (!(filter instanceof ActiveFilter))
    return;

  if (!filter.disabled)
  {
    let hasEnabled = false;
    for (let i = 0; i < filter.subscriptions.length; i++)
    {
      if (!filter.subscriptions[i].disabled)
        hasEnabled = true;
    }
    if (hasEnabled)
      return;
  }

  if (filter instanceof RegExpFilter)
    defaultMatcher.remove(filter);
  else if (filter instanceof ElemHideBase)
  {
    if (filter instanceof ElemHideEmulationFilter)
      ElemHideEmulation.remove(filter);
    else
      ElemHide.remove(filter);
  }
}

const primes = [101, 109, 131, 149, 163, 179, 193, 211, 229, 241];

function addFilters(filters)
{
  // We add filters using pseudo-random ordering. Reason is that ElemHide will
  // assign consecutive filter IDs that might be visible to the website. The
  // randomization makes sure that no conclusion can be made about the actual
  // filters applying there. We have ten prime numbers to use as iteration step,
  // any of those can be chosen as long as the array length isn't divisible by
  // it.
  let len = filters.length;
  if (!len)
    return;

  let current = (Math.random() * len) | 0;
  let step;
  do
  {
    step = primes[(Math.random() * primes.length) | 0];
  } while (len % step == 0);

  for (let i = 0; i < len; i++, current = (current + step) % len)
    addFilter(filters[current]);
}

function onSubscriptionAdded(subscription)
{
  FilterListener.setDirty(1);

  if (!subscription.disabled)
    addFilters(subscription.filters);
}

function onSubscriptionRemoved(subscription)
{
  FilterListener.setDirty(1);

  if (!subscription.disabled)
    subscription.filters.forEach(removeFilter);
}

function onSubscriptionDisabled(subscription, newValue)
{
  FilterListener.setDirty(1);

  if (subscription.url in FilterStorage.knownSubscriptions)
  {
    if (newValue == false)
      addFilters(subscription.filters);
    else
      subscription.filters.forEach(removeFilter);
  }
}

function onSubscriptionUpdated(subscription)
{
  FilterListener.setDirty(1);

  if (subscription.url in FilterStorage.knownSubscriptions &&
      !subscription.disabled)
  {
    subscription.oldFilters.forEach(removeFilter);
    addFilters(subscription.filters);
  }
}

function onFilterHitCount(filter, newValue)
{
  if (newValue == 0)
    FilterListener.setDirty(0);
  else
    FilterListener.setDirty(0.002);
}

function onFilterLastHit()
{
  FilterListener.setDirty(0.002);
}

function onFilterAdded(filter)
{
  FilterListener.setDirty(1);

  if (!filter.disabled)
    addFilter(filter);
}

function onFilterRemoved(filter)
{
  FilterListener.setDirty(1);

  if (!filter.disabled)
    removeFilter(filter);
}

function onFilterDisabled(filter, newValue)
{
  FilterListener.setDirty(1);

  if (newValue == false)
    addFilter(filter);
  else
    removeFilter(filter);
}

function onGenericChange()
{
  FilterListener.setDirty(1);
}

function onLoad()
{
  isDirty = 0;

  defaultMatcher.clear();
  ElemHide.clear();
  ElemHideEmulation.clear();
  for (let subscription of FilterStorage.subscriptions)
  {
    if (!subscription.disabled)
      addFilters(subscription.filters);
  }
}

function onSave()
{
  isDirty = 0;
}

return module.exports;
};

require.modules["filterNotifier"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview This component manages listeners and calls them to distributes
 * messages about filter changes.
 */

const {EventEmitter} = require("events");
const {desc} = require("coreUtils");

const CATCH_ALL = "__all";

/**
 * @callback FilterNotifierCatchAllListener
 * @param {string} action
 * @param {Subscription|Filter} item
 * @param {...*} additionalInfo
 */

/**
 * This class allows registering and triggering listeners for filter events.
 * @class
 */
exports.FilterNotifier = Object.create(new EventEmitter(), desc({
  /**
   * Adds a listener
   *
   * @deprecated use FilterNotifier.on(action, callback)
   * @param {FilterNotifierCatchAllListener} listener
   */
  addListener(listener)
  {
    let listeners = this._listeners[CATCH_ALL];
    if (!listeners || listeners.indexOf(listener) == -1)
      this.on(CATCH_ALL, listener);
  },

  /**
   * Removes a listener that was previosly added via addListener
   *
   * @deprecated use FilterNotifier.off(action, callback)
   * @param {FilterNotifierCatchAllListener} listener
   */
  removeListener(listener)
  {
    this.off(CATCH_ALL, listener);
  },

  /**
   * Notifies listeners about an event
   * @param {string} action event code ("load", "save", "elemhideupdate",
   *                 "subscription.added", "subscription.removed",
   *                 "subscription.disabled", "subscription.title",
   *                 "subscription.lastDownload", "subscription.downloadStatus",
   *                 "subscription.homepage", "subscription.updated",
   *                 "filter.added", "filter.removed", "filter.moved",
   *                 "filter.disabled", "filter.hitCount", "filter.lastHit")
   * @param {Subscription|Filter} item item that the change applies to
   * @param {*} param1
   * @param {*} param2
   * @param {*} param3
   * @deprecated use FilterNotifier.emit(action)
   */
  triggerListeners(action, item, param1, param2, param3)
  {
    this.emit(action, item, param1, param2, param3);
    this.emit(CATCH_ALL, action, item, param1, param2, param3);
  }
}));

return module.exports;
};

require.modules["filterStorage"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview FilterStorage class responsible for managing user's
 *               subscriptions and filters.
 */

const {IO} = require("io");
const {Prefs} = require("prefs");
const {Filter, ActiveFilter} = require("filterClasses");
const {Subscription, SpecialSubscription,
       ExternalSubscription} = require("subscriptionClasses");
const {FilterNotifier} = require("filterNotifier");

/**
 * Version number of the filter storage file format.
 * @type {number}
 */
let formatVersion = 5;

/**
 * This class reads user's filters from disk, manages them in memory
 * and writes them back.
 * @class
 */
let FilterStorage = exports.FilterStorage =
{
  /**
   * Will be set to true after the initial loadFromDisk() call completes.
   * @type {boolean}
   */
  initialized: false,

  /**
   * Version number of the patterns.ini format used.
   * @type {number}
   */
  get formatVersion()
  {
    return formatVersion;
  },

  /**
   * File containing the filter list
   * @type {string}
   */
  get sourceFile()
  {
    return "patterns.ini";
  },

  /**
   * Will be set to true if no patterns.ini file exists.
   * @type {boolean}
   */
  firstRun: false,

  /**
   * Map of properties listed in the filter storage file before the sections
   * start. Right now this should be only the format version.
   */
  fileProperties: Object.create(null),

  /**
   * List of filter subscriptions containing all filters
   * @type {Subscription[]}
   */
  subscriptions: [],

  /**
   * Map of subscriptions already on the list, by their URL/identifier
   * @type {Object}
   */
  knownSubscriptions: Object.create(null),

  /**
   * Finds the filter group that a filter should be added to by default. Will
   * return null if this group doesn't exist yet.
   * @param {Filter} filter
   * @return {?SpecialSubscription}
   */
  getGroupForFilter(filter)
  {
    let generalSubscription = null;
    for (let subscription of FilterStorage.subscriptions)
    {
      if (subscription instanceof SpecialSubscription && !subscription.disabled)
      {
        // Always prefer specialized subscriptions
        if (subscription.isDefaultFor(filter))
          return subscription;

        // If this is a general subscription - store it as fallback
        if (!generalSubscription &&
            (!subscription.defaults || !subscription.defaults.length))
        {
          generalSubscription = subscription;
        }
      }
    }
    return generalSubscription;
  },

  /**
   * Adds a filter subscription to the list
   * @param {Subscription} subscription filter subscription to be added
   */
  addSubscription(subscription)
  {
    if (subscription.url in FilterStorage.knownSubscriptions)
      return;

    FilterStorage.subscriptions.push(subscription);
    FilterStorage.knownSubscriptions[subscription.url] = subscription;
    addSubscriptionFilters(subscription);

    FilterNotifier.triggerListeners("subscription.added", subscription);
  },

  /**
   * Removes a filter subscription from the list
   * @param {Subscription} subscription filter subscription to be removed
   */
  removeSubscription(subscription)
  {
    for (let i = 0; i < FilterStorage.subscriptions.length; i++)
    {
      if (FilterStorage.subscriptions[i].url == subscription.url)
      {
        removeSubscriptionFilters(subscription);

        FilterStorage.subscriptions.splice(i--, 1);
        delete FilterStorage.knownSubscriptions[subscription.url];
        FilterNotifier.triggerListeners("subscription.removed", subscription);
        return;
      }
    }
  },

  /**
   * Moves a subscription in the list to a new position.
   * @param {Subscription} subscription filter subscription to be moved
   * @param {Subscription} [insertBefore] filter subscription to insert before
   *        (if omitted the subscription will be put at the end of the list)
   */
  moveSubscription(subscription, insertBefore)
  {
    let currentPos = FilterStorage.subscriptions.indexOf(subscription);
    if (currentPos < 0)
      return;

    let newPos = -1;
    if (insertBefore)
      newPos = FilterStorage.subscriptions.indexOf(insertBefore);

    if (newPos < 0)
      newPos = FilterStorage.subscriptions.length;

    if (currentPos < newPos)
      newPos--;
    if (currentPos == newPos)
      return;

    FilterStorage.subscriptions.splice(currentPos, 1);
    FilterStorage.subscriptions.splice(newPos, 0, subscription);
    FilterNotifier.triggerListeners("subscription.moved", subscription);
  },

  /**
   * Replaces the list of filters in a subscription by a new list
   * @param {Subscription} subscription filter subscription to be updated
   * @param {Filter[]} filters new filter list
   */
  updateSubscriptionFilters(subscription, filters)
  {
    removeSubscriptionFilters(subscription);
    subscription.oldFilters = subscription.filters;
    subscription.filters = filters;
    addSubscriptionFilters(subscription);
    FilterNotifier.triggerListeners("subscription.updated", subscription);
    delete subscription.oldFilters;
  },

  /**
   * Adds a user-defined filter to the list
   * @param {Filter} filter
   * @param {SpecialSubscription} [subscription]
   *   particular group that the filter should be added to
   * @param {number} [position]
   *   position within the subscription at which the filter should be added
   */
  addFilter(filter, subscription, position)
  {
    if (!subscription)
    {
      if (filter.subscriptions.some(s => s instanceof SpecialSubscription &&
                                         !s.disabled))
      {
        return;   // No need to add
      }
      subscription = FilterStorage.getGroupForFilter(filter);
    }
    if (!subscription)
    {
      // No group for this filter exists, create one
      subscription = SpecialSubscription.createForFilter(filter);
      this.addSubscription(subscription);
      return;
    }

    if (typeof position == "undefined")
      position = subscription.filters.length;

    if (filter.subscriptions.indexOf(subscription) < 0)
      filter.subscriptions.push(subscription);
    subscription.filters.splice(position, 0, filter);
    FilterNotifier.triggerListeners("filter.added", filter, subscription,
                                    position);
  },

  /**
   * Removes a user-defined filter from the list
   * @param {Filter} filter
   * @param {SpecialSubscription} [subscription] a particular filter group that
   *      the filter should be removed from (if ommited will be removed from all
   *      subscriptions)
   * @param {number} [position]  position inside the filter group at which the
   *      filter should be removed (if ommited all instances will be removed)
   */
  removeFilter(filter, subscription, position)
  {
    let subscriptions = (
      subscription ? [subscription] : filter.subscriptions.slice()
    );
    for (let i = 0; i < subscriptions.length; i++)
    {
      let currentSubscription = subscriptions[i];
      if (currentSubscription instanceof SpecialSubscription)
      {
        let positions = [];
        if (typeof position == "undefined")
        {
          let index = -1;
          do
          {
            index = currentSubscription.filters.indexOf(filter, index + 1);
            if (index >= 0)
              positions.push(index);
          } while (index >= 0);
        }
        else
          positions.push(position);

        for (let j = positions.length - 1; j >= 0; j--)
        {
          let currentPosition = positions[j];
          if (currentSubscription.filters[currentPosition] == filter)
          {
            currentSubscription.filters.splice(currentPosition, 1);
            if (currentSubscription.filters.indexOf(filter) < 0)
            {
              let index = filter.subscriptions.indexOf(currentSubscription);
              if (index >= 0)
                filter.subscriptions.splice(index, 1);
            }
            FilterNotifier.triggerListeners(
              "filter.removed", filter, currentSubscription, currentPosition
            );
          }
        }
      }
    }
  },

  /**
   * Moves a user-defined filter to a new position
   * @param {Filter} filter
   * @param {SpecialSubscription} subscription filter group where the filter is
   *                                           located
   * @param {number} oldPosition current position of the filter
   * @param {number} newPosition new position of the filter
   */
  moveFilter(filter, subscription, oldPosition, newPosition)
  {
    if (!(subscription instanceof SpecialSubscription) ||
        subscription.filters[oldPosition] != filter)
    {
      return;
    }

    newPosition = Math.min(Math.max(newPosition, 0),
                           subscription.filters.length - 1);
    if (oldPosition == newPosition)
      return;

    subscription.filters.splice(oldPosition, 1);
    subscription.filters.splice(newPosition, 0, filter);
    FilterNotifier.triggerListeners("filter.moved", filter, subscription,
                                    oldPosition, newPosition);
  },

  /**
   * Increases the hit count for a filter by one
   * @param {Filter} filter
   */
  increaseHitCount(filter)
  {
    if (!Prefs.savestats || !(filter instanceof ActiveFilter))
      return;

    filter.hitCount++;
    filter.lastHit = Date.now();
  },

  /**
   * Resets hit count for some filters
   * @param {Filter[]} filters  filters to be reset, if null all filters will
   *                            be reset
   */
  resetHitCounts(filters)
  {
    if (!filters)
    {
      filters = [];
      for (let text in Filter.knownFilters)
        filters.push(Filter.knownFilters[text]);
    }
    for (let filter of filters)
    {
      filter.hitCount = 0;
      filter.lastHit = 0;
    }
  },

  /**
   * @callback TextSink
   * @param {string?} line
   */

  /**
   * Allows importing previously serialized filter data.
   * @param {boolean} silent
   *    If true, no "load" notification will be sent out.
   * @return {TextSink}
   *    Function to be called for each line of data. Calling it with null as
   *    parameter finalizes the import and replaces existing data. No changes
   *    will be applied before finalization, so import can be "aborted" by
   *    forgetting this callback.
   */
  importData(silent)
  {
    let parser = new INIParser();
    return line =>
    {
      parser.process(line);
      if (line === null)
      {
        let knownSubscriptions = Object.create(null);
        for (let subscription of parser.subscriptions)
          knownSubscriptions[subscription.url] = subscription;

        this.fileProperties = parser.fileProperties;
        this.subscriptions = parser.subscriptions;
        this.knownSubscriptions = knownSubscriptions;
        Filter.knownFilters = parser.knownFilters;
        Subscription.knownSubscriptions = parser.knownSubscriptions;

        if (!silent)
          FilterNotifier.triggerListeners("load");
      }
    };
  },

  /**
   * Loads all subscriptions from the disk.
   * @return {Promise} promise resolved or rejected when loading is complete
   */
  loadFromDisk()
  {
    let tryBackup = backupIndex =>
    {
      return this.restoreBackup(backupIndex, true).then(() =>
      {
        if (this.subscriptions.length == 0)
          return tryBackup(backupIndex + 1);
      }).catch(error =>
      {
        // Give up
      });
    };

    return IO.statFile(this.sourceFile).then(statData =>
    {
      if (!statData.exists)
      {
        this.firstRun = true;
        return;
      }

      let parser = this.importData(true);
      return IO.readFromFile(this.sourceFile, parser).then(() =>
      {
        parser(null);
        if (this.subscriptions.length == 0)
        {
          // No filter subscriptions in the file, this isn't right.
          throw new Error("No data in the file");
        }
      });
    }).catch(error =>
    {
      Cu.reportError(error);
      return tryBackup(1);
    }).then(() =>
    {
      this.initialized = true;
      FilterNotifier.triggerListeners("load");
    });
  },

  /**
   * Constructs the file name for a patterns.ini backup.
   * @param {number} backupIndex
   *    number of the backup file (1 being the most recent)
   * @return {string} backup file name
   */
  getBackupName(backupIndex)
  {
    let [name, extension] = this.sourceFile.split(".", 2);
    return (name + "-backup" + backupIndex + "." + extension);
  },

  /**
   * Restores an automatically created backup.
   * @param {number} backupIndex
   *    number of the backup to restore (1 being the most recent)
   * @param {boolean} silent
   *    If true, no "load" notification will be sent out.
   * @return {Promise} promise resolved or rejected when restoring is complete
   */
  restoreBackup(backupIndex, silent)
  {
    let backupFile = this.getBackupName(backupIndex);
    let parser = this.importData(silent);
    return IO.readFromFile(backupFile, parser).then(() =>
    {
      parser(null);
      return this.saveToDisk();
    });
  },

  /**
   * Generator serializing filter data and yielding it line by line.
   */
  *exportData()
  {
    // Do not persist external subscriptions
    let subscriptions = this.subscriptions.filter(
      s => !(s instanceof ExternalSubscription)
    );

    yield "# Adblock Plus preferences";
    yield "version=" + formatVersion;

    let saved = new Set();
    let buf = [];

    // Save subscriptions
    for (let subscription of subscriptions)
    {
      yield "";

      subscription.serialize(buf);
      if (subscription.filters.length)
      {
        buf.push("", "[Subscription filters]");
        subscription.serializeFilters(buf);
      }
      for (let line of buf)
        yield line;
      buf.splice(0);
    }

    // Save filter data
    for (let subscription of subscriptions)
    {
      for (let filter of subscription.filters)
      {
        if (!saved.has(filter.text))
        {
          filter.serialize(buf);
          saved.add(filter.text);
          for (let line of buf)
            yield line;
          buf.splice(0);
        }
      }
    }
  },

  /**
   * Will be set to true if saveToDisk() is running (reentrance protection).
   * @type {boolean}
   */
  _saving: false,

  /**
   * Will be set to true if a saveToDisk() call arrives while saveToDisk() is
   * already running (delayed execution).
   * @type {boolean}
   */
  _needsSave: false,

  /**
   * Saves all subscriptions back to disk
   * @return {Promise} promise resolved or rejected when saving is complete
   */
  saveToDisk()
  {
    if (this._saving)
    {
      this._needsSave = true;
      return;
    }

    this._saving = true;

    return Promise.resolve().then(() =>
    {
      // First check whether we need to create a backup
      if (Prefs.patternsbackups <= 0)
        return false;

      return IO.statFile(this.sourceFile).then(statData =>
      {
        if (!statData.exists)
          return false;

        return IO.statFile(this.getBackupName(1)).then(backupStatData =>
        {
          if (backupStatData.exists &&
              (Date.now() - backupStatData.lastModified) / 3600000 <
                Prefs.patternsbackupinterval)
          {
            return false;
          }
          return true;
        });
      });
    }).then(backupRequired =>
    {
      if (!backupRequired)
        return;

      let ignoreErrors = error =>
      {
        // Expected error, backup file doesn't exist.
      };

      let renameBackup = index =>
      {
        if (index > 0)
        {
          return IO.renameFile(this.getBackupName(index),
                               this.getBackupName(index + 1))
                   .catch(ignoreErrors)
                   .then(() => renameBackup(index - 1));
        }

        return IO.renameFile(this.sourceFile, this.getBackupName(1))
                 .catch(ignoreErrors);
      };

      // Rename existing files
      return renameBackup(Prefs.patternsbackups - 1);
    }).catch(error =>
    {
      // Errors during backup creation shouldn't prevent writing filters.
      Cu.reportError(error);
    }).then(() =>
    {
      return IO.writeToFile(this.sourceFile, this.exportData());
    }).then(() =>
    {
      FilterNotifier.triggerListeners("save");
    }).catch(error =>
    {
      // If saving failed, report error but continue - we still have to process
      // flags.
      Cu.reportError(error);
    }).then(() =>
    {
      this._saving = false;
      if (this._needsSave)
      {
        this._needsSave = false;
        this.saveToDisk();
      }
    });
  },

  /**
   * @typedef FileInfo
   * @type {object}
   * @property {nsIFile} file
   * @property {number} lastModified
   */

  /**
   * Returns a promise resolving in a list of existing backup files.
   * @return {Promise.<FileInfo[]>}
   */
  getBackupFiles()
  {
    let backups = [];

    let checkBackupFile = index =>
    {
      return IO.statFile(this.getBackupName(index)).then(statData =>
      {
        if (!statData.exists)
          return backups;

        backups.push({
          index,
          lastModified: statData.lastModified
        });
        return checkBackupFile(index + 1);
      }).catch(error =>
      {
        // Something went wrong, return whatever data we got so far.
        Cu.reportError(error);
        return backups;
      });
    };

    return checkBackupFile(1);
  }
};

/**
 * Joins subscription's filters to the subscription without any notifications.
 * @param {Subscription} subscription
 *   filter subscription that should be connected to its filters
 */
function addSubscriptionFilters(subscription)
{
  if (!(subscription.url in FilterStorage.knownSubscriptions))
    return;

  for (let filter of subscription.filters)
    filter.subscriptions.push(subscription);
}

/**
 * Removes subscription's filters from the subscription without any
 * notifications.
 * @param {Subscription} subscription filter subscription to be removed
 */
function removeSubscriptionFilters(subscription)
{
  if (!(subscription.url in FilterStorage.knownSubscriptions))
    return;

  for (let filter of subscription.filters)
  {
    let i = filter.subscriptions.indexOf(subscription);
    if (i >= 0)
      filter.subscriptions.splice(i, 1);
  }
}

/**
 * Listener returned by FilterStorage.importData(), parses filter data.
 * @constructor
 */
function INIParser()
{
  this.fileProperties = this.curObj = {};
  this.subscriptions = [];
  this.knownFilters = Object.create(null);
  this.knownSubscriptions = Object.create(null);
}
INIParser.prototype =
{
  linesProcessed: 0,
  subscriptions: null,
  knownFilters: null,
  knownSubscriptions: null,
  wantObj: true,
  fileProperties: null,
  curObj: null,
  curSection: null,

  process(val)
  {
    let origKnownFilters = Filter.knownFilters;
    Filter.knownFilters = this.knownFilters;
    let origKnownSubscriptions = Subscription.knownSubscriptions;
    Subscription.knownSubscriptions = this.knownSubscriptions;
    let match;
    try
    {
      if (this.wantObj === true && (match = /^(\w+)=(.*)$/.exec(val)))
        this.curObj[match[1]] = match[2];
      else if (val === null || (match = /^\s*\[(.+)\]\s*$/.exec(val)))
      {
        if (this.curObj)
        {
          // Process current object before going to next section
          switch (this.curSection)
          {
            case "filter":
              if ("text" in this.curObj)
                Filter.fromObject(this.curObj);
              break;
            case "subscription": {
              let subscription = Subscription.fromObject(this.curObj);
              if (subscription)
                this.subscriptions.push(subscription);
              break;
            }
            case "subscription filters":
              if (this.subscriptions.length)
              {
                let subscription = this.subscriptions[
                  this.subscriptions.length - 1
                ];
                for (let text of this.curObj)
                {
                  let filter = Filter.fromText(text);
                  subscription.filters.push(filter);
                  filter.subscriptions.push(subscription);
                }
              }
              break;
          }
        }

        if (val === null)
          return;

        this.curSection = match[1].toLowerCase();
        switch (this.curSection)
        {
          case "filter":
          case "subscription":
            this.wantObj = true;
            this.curObj = {};
            break;
          case "subscription filters":
            this.wantObj = false;
            this.curObj = [];
            break;
          default:
            this.wantObj = undefined;
            this.curObj = null;
        }
      }
      else if (this.wantObj === false && val)
        this.curObj.push(val.replace(/\\\[/g, "["));
    }
    finally
    {
      Filter.knownFilters = origKnownFilters;
      Subscription.knownSubscriptions = origKnownSubscriptions;
    }
  }
};

return module.exports;
};

require.modules["jsbn"] = function(module, exports)
{
/*
 * Copyright (c) 2003-2005  Tom Wu
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS-IS" AND WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS, IMPLIED OR OTHERWISE, INCLUDING WITHOUT LIMITATION, ANY
 * WARRANTY OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
 *
 * IN NO EVENT SHALL TOM WU BE LIABLE FOR ANY SPECIAL, INCIDENTAL,
 * INDIRECT OR CONSEQUENTIAL DAMAGES OF ANY KIND, OR ANY DAMAGES WHATSOEVER
 * RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER OR NOT ADVISED OF
 * THE POSSIBILITY OF DAMAGE, AND ON ANY THEORY OF LIABILITY, ARISING OUT
 * OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * In addition, the following condition applies:
 *
 * All redistributions must retain an intact copy of this copyright notice
 * and disclaimer.
 */

// Basic JavaScript BN library - subset useful for RSA encryption.

// Bits per digit
var dbits;

// JavaScript engine analysis
var canary = 0xdeadbeefcafe;
var j_lm = ((canary&0xffffff)==0xefcafe);

// (public) Constructor
function BigInteger(a,b,c) {
  if(a != null)
    if("number" == typeof a) this.fromNumber(a,b,c);
    else if(b == null && "string" != typeof a) this.fromString(a,256);
    else this.fromString(a,b);
}
exports.BigInteger = BigInteger;

// return new, unset BigInteger
function nbi() { return new BigInteger(null); }

// am: Compute w_j += (x*this_i), propagate carries,
// c is initial carry, returns final carry.
// c < 3*dvalue, x < 2*dvalue, this_i < dvalue
// We need to select the fastest one that works in this environment.

// am1: use a single mult and divide to get the high bits,
// max digit bits should be 26 because
// max internal value = 2*dvalue^2-2*dvalue (< 2^53)
function am1(i,x,w,j,c,n) {
  while(--n >= 0) {
    var v = x*this[i++]+w[j]+c;
    c = Math.floor(v/0x4000000);
    w[j++] = v&0x3ffffff;
  }
  return c;
}
// am2 avoids a big mult-and-extract completely.
// Max digit bits should be <= 30 because we do bitwise ops
// on values up to 2*hdvalue^2-hdvalue-1 (< 2^31)
function am2(i,x,w,j,c,n) {
  var xl = x&0x7fff, xh = x>>15;
  while(--n >= 0) {
    var l = this[i]&0x7fff;
    var h = this[i++]>>15;
    var m = xh*l+h*xl;
    l = xl*l+((m&0x7fff)<<15)+w[j]+(c&0x3fffffff);
    c = (l>>>30)+(m>>>15)+xh*h+(c>>>30);
    w[j++] = l&0x3fffffff;
  }
  return c;
}
// Alternately, set max digit bits to 28 since some
// browsers slow down when dealing with 32-bit numbers.
function am3(i,x,w,j,c,n) {
  var xl = x&0x3fff, xh = x>>14;
  while(--n >= 0) {
    var l = this[i]&0x3fff;
    var h = this[i++]>>14;
    var m = xh*l+h*xl;
    l = xl*l+((m&0x3fff)<<14)+w[j]+c;
    c = (l>>28)+(m>>14)+xh*h;
    w[j++] = l&0xfffffff;
  }
  return c;
}
if(j_lm && (navigator.appName == "Microsoft Internet Explorer")) {
  BigInteger.prototype.am = am2;
  dbits = 30;
}
else if(j_lm && (navigator.appName != "Netscape")) {
  BigInteger.prototype.am = am1;
  dbits = 26;
}
else { // Mozilla/Netscape seems to prefer am3
  BigInteger.prototype.am = am3;
  dbits = 28;
}

BigInteger.prototype.DB = dbits;
BigInteger.prototype.DM = ((1<<dbits)-1);
BigInteger.prototype.DV = (1<<dbits);

var BI_FP = 52;
BigInteger.prototype.FV = Math.pow(2,BI_FP);
BigInteger.prototype.F1 = BI_FP-dbits;
BigInteger.prototype.F2 = 2*dbits-BI_FP;

// Digit conversions
var BI_RM = "0123456789abcdefghijklmnopqrstuvwxyz";
var BI_RC = new Array();
var rr,vv;
rr = "0".charCodeAt(0);
for(vv = 0; vv <= 9; ++vv) BI_RC[rr++] = vv;
rr = "a".charCodeAt(0);
for(vv = 10; vv < 36; ++vv) BI_RC[rr++] = vv;
rr = "A".charCodeAt(0);
for(vv = 10; vv < 36; ++vv) BI_RC[rr++] = vv;

function int2char(n) { return BI_RM.charAt(n); }
function intAt(s,i) {
  var c = BI_RC[s.charCodeAt(i)];
  return (c==null)?-1:c;
}

// (protected) copy this to r
function bnpCopyTo(r) {
  for(var i = this.t-1; i >= 0; --i) r[i] = this[i];
  r.t = this.t;
  r.s = this.s;
}

// (protected) set from integer value x, -DV <= x < DV
function bnpFromInt(x) {
  this.t = 1;
  this.s = (x<0)?-1:0;
  if(x > 0) this[0] = x;
  else if(x < -1) this[0] = x+DV;
  else this.t = 0;
}

// return bigint initialized to value
function nbv(i) { var r = nbi(); r.fromInt(i); return r; }

// (protected) set from string and radix
function bnpFromString(s,b) {
  var k;
  if(b == 16) k = 4;
  else if(b == 8) k = 3;
  else if(b == 256) k = 8; // byte array
  else if(b == 2) k = 1;
  else if(b == 32) k = 5;
  else if(b == 4) k = 2;
  else { this.fromRadix(s,b); return; }
  this.t = 0;
  this.s = 0;
  var i = s.length, mi = false, sh = 0;
  while(--i >= 0) {
    var x = (k==8)?s.charCodeAt(i)&0xff:intAt(s,i);   /** MODIFIED **/
    if(x < 0) {
      if(s.charAt(i) == "-") mi = true;
      continue;
    }
    mi = false;
    if(sh == 0)
      this[this.t++] = x;
    else if(sh+k > this.DB) {
      this[this.t-1] |= (x&((1<<(this.DB-sh))-1))<<sh;
      this[this.t++] = (x>>(this.DB-sh));
    }
    else
      this[this.t-1] |= x<<sh;
    sh += k;
    if(sh >= this.DB) sh -= this.DB;
  }
  if(k == 8 && (s[0]&0x80) != 0) {
    this.s = -1;
    if(sh > 0) this[this.t-1] |= ((1<<(this.DB-sh))-1)<<sh;
  }
  this.clamp();
  if(mi) BigInteger.ZERO.subTo(this,this);
}

// (protected) clamp off excess high words
function bnpClamp() {
  var c = this.s&this.DM;
  while(this.t > 0 && this[this.t-1] == c) --this.t;
}

// (public) return string representation in given radix
function bnToString(b) {
  if(this.s < 0) return "-"+this.negate().toString(b);
  var k;
  if(b == 16) k = 4;
  else if(b == 8) k = 3;
  else if(b == 256) k = 8; // byte array      /** MODIFIED **/
  else if(b == 2) k = 1;
  else if(b == 32) k = 5;
  else if(b == 4) k = 2;
  else return this.toRadix(b);
  var km = (1<<k)-1, d, m = false, r = "", i = this.t;
  var p = this.DB-(i*this.DB)%k;
  if(i-- > 0) {
    if(p < this.DB && (d = this[i]>>p) > 0) { m = true; r = (k==8)?String.fromCharCode(d):int2char(d); }   /** MODIFIED **/
    while(i >= 0) {
      if(p < k) {
        d = (this[i]&((1<<p)-1))<<(k-p);
        d |= this[--i]>>(p+=this.DB-k);
      }
      else {
        d = (this[i]>>(p-=k))&km;
        if(p <= 0) { p += this.DB; --i; }
      }
      if(d > 0) m = true;
      if(m) r += (k==8)?String.fromCharCode(d):int2char(d);    /** MODIFIED **/
    }
  }
  return m?r:"0";
}

// (public) -this
function bnNegate() { var r = nbi(); BigInteger.ZERO.subTo(this,r); return r; }

// (public) |this|
function bnAbs() { return (this.s<0)?this.negate():this; }

// (public) return + if this > a, - if this < a, 0 if equal
function bnCompareTo(a) {
  var r = this.s-a.s;
  if(r != 0) return r;
  var i = this.t;
  r = i-a.t;
  if(r != 0) return r;
  while(--i >= 0) if((r=this[i]-a[i]) != 0) return r;
  return 0;
}

// returns bit length of the integer x
function nbits(x) {
  var r = 1, t;
  if((t=x>>>16) != 0) { x = t; r += 16; }
  if((t=x>>8) != 0) { x = t; r += 8; }
  if((t=x>>4) != 0) { x = t; r += 4; }
  if((t=x>>2) != 0) { x = t; r += 2; }
  if((t=x>>1) != 0) { x = t; r += 1; }
  return r;
}

// (public) return the number of bits in "this"
function bnBitLength() {
  if(this.t <= 0) return 0;
  return this.DB*(this.t-1)+nbits(this[this.t-1]^(this.s&this.DM));
}

// (protected) r = this << n*DB
function bnpDLShiftTo(n,r) {
  var i;
  for(i = this.t-1; i >= 0; --i) r[i+n] = this[i];
  for(i = n-1; i >= 0; --i) r[i] = 0;
  r.t = this.t+n;
  r.s = this.s;
}

// (protected) r = this >> n*DB
function bnpDRShiftTo(n,r) {
  for(var i = n; i < this.t; ++i) r[i-n] = this[i];
  r.t = Math.max(this.t-n,0);
  r.s = this.s;
}

// (protected) r = this << n
function bnpLShiftTo(n,r) {
  var bs = n%this.DB;
  var cbs = this.DB-bs;
  var bm = (1<<cbs)-1;
  var ds = Math.floor(n/this.DB), c = (this.s<<bs)&this.DM, i;
  for(i = this.t-1; i >= 0; --i) {
    r[i+ds+1] = (this[i]>>cbs)|c;
    c = (this[i]&bm)<<bs;
  }
  for(i = ds-1; i >= 0; --i) r[i] = 0;
  r[ds] = c;
  r.t = this.t+ds+1;
  r.s = this.s;
  r.clamp();
}

// (protected) r = this >> n
function bnpRShiftTo(n,r) {
  r.s = this.s;
  var ds = Math.floor(n/this.DB);
  if(ds >= this.t) { r.t = 0; return; }
  var bs = n%this.DB;
  var cbs = this.DB-bs;
  var bm = (1<<bs)-1;
  r[0] = this[ds]>>bs;
  for(var i = ds+1; i < this.t; ++i) {
    r[i-ds-1] |= (this[i]&bm)<<cbs;
    r[i-ds] = this[i]>>bs;
  }
  if(bs > 0) r[this.t-ds-1] |= (this.s&bm)<<cbs;
  r.t = this.t-ds;
  r.clamp();
}

// (protected) r = this - a
function bnpSubTo(a,r) {
  var i = 0, c = 0, m = Math.min(a.t,this.t);
  while(i < m) {
    c += this[i]-a[i];
    r[i++] = c&this.DM;
    c >>= this.DB;
  }
  if(a.t < this.t) {
    c -= a.s;
    while(i < this.t) {
      c += this[i];
      r[i++] = c&this.DM;
      c >>= this.DB;
    }
    c += this.s;
  }
  else {
    c += this.s;
    while(i < a.t) {
      c -= a[i];
      r[i++] = c&this.DM;
      c >>= this.DB;
    }
    c -= a.s;
  }
  r.s = (c<0)?-1:0;
  if(c < -1) r[i++] = this.DV+c;
  else if(c > 0) r[i++] = c;
  r.t = i;
  r.clamp();
}

// (protected) r = this * a, r != this,a (HAC 14.12)
// "this" should be the larger one if appropriate.
function bnpMultiplyTo(a,r) {
  var x = this.abs(), y = a.abs();
  var i = x.t;
  r.t = i+y.t;
  while(--i >= 0) r[i] = 0;
  for(i = 0; i < y.t; ++i) r[i+x.t] = x.am(0,y[i],r,i,0,x.t);
  r.s = 0;
  r.clamp();
  if(this.s != a.s) BigInteger.ZERO.subTo(r,r);
}

// (protected) r = this^2, r != this (HAC 14.16)
function bnpSquareTo(r) {
  var x = this.abs();
  var i = r.t = 2*x.t;
  while(--i >= 0) r[i] = 0;
  for(i = 0; i < x.t-1; ++i) {
    var c = x.am(i,x[i],r,2*i,0,1);
    if((r[i+x.t]+=x.am(i+1,2*x[i],r,2*i+1,c,x.t-i-1)) >= x.DV) {
      r[i+x.t] -= x.DV;
      r[i+x.t+1] = 1;
    }
  }
  if(r.t > 0) r[r.t-1] += x.am(i,x[i],r,2*i,0,1);
  r.s = 0;
  r.clamp();
}

// (protected) divide this by m, quotient and remainder to q, r (HAC 14.20)
// r != q, this != m.  q or r may be null.
function bnpDivRemTo(m,q,r) {
  var pm = m.abs();
  if(pm.t <= 0) return;
  var pt = this.abs();
  if(pt.t < pm.t) {
    if(q != null) q.fromInt(0);
    if(r != null) this.copyTo(r);
    return;
  }
  if(r == null) r = nbi();
  var y = nbi(), ts = this.s, ms = m.s;
  var nsh = this.DB-nbits(pm[pm.t-1]);	// normalize modulus
  if(nsh > 0) { pm.lShiftTo(nsh,y); pt.lShiftTo(nsh,r); }
  else { pm.copyTo(y); pt.copyTo(r); }
  var ys = y.t;
  var y0 = y[ys-1];
  if(y0 == 0) return;
  var yt = y0*(1<<this.F1)+((ys>1)?y[ys-2]>>this.F2:0);
  var d1 = this.FV/yt, d2 = (1<<this.F1)/yt, e = 1<<this.F2;
  var i = r.t, j = i-ys, t = (q==null)?nbi():q;
  y.dlShiftTo(j,t);
  if(r.compareTo(t) >= 0) {
    r[r.t++] = 1;
    r.subTo(t,r);
  }
  BigInteger.ONE.dlShiftTo(ys,t);
  t.subTo(y,y);	// "negative" y so we can replace sub with am later
  while(y.t < ys) y[y.t++] = 0;
  while(--j >= 0) {
    // Estimate quotient digit
    var qd = (r[--i]==y0)?this.DM:Math.floor(r[i]*d1+(r[i-1]+e)*d2);
    if((r[i]+=y.am(0,qd,r,j,0,ys)) < qd) {	// Try it out
      y.dlShiftTo(j,t);
      r.subTo(t,r);
      while(r[i] < --qd) r.subTo(t,r);
    }
  }
  if(q != null) {
    r.drShiftTo(ys,q);
    if(ts != ms) BigInteger.ZERO.subTo(q,q);
  }
  r.t = ys;
  r.clamp();
  if(nsh > 0) r.rShiftTo(nsh,r);	// Denormalize remainder
  if(ts < 0) BigInteger.ZERO.subTo(r,r);
}

// (public) this mod a
function bnMod(a) {
  var r = nbi();
  this.abs().divRemTo(a,null,r);
  if(this.s < 0 && r.compareTo(BigInteger.ZERO) > 0) a.subTo(r,r);
  return r;
}

// Modular reduction using "classic" algorithm
function Classic(m) { this.m = m; }
function cConvert(x) {
  if(x.s < 0 || x.compareTo(this.m) >= 0) return x.mod(this.m);
  else return x;
}
function cRevert(x) { return x; }
function cReduce(x) { x.divRemTo(this.m,null,x); }
function cMulTo(x,y,r) { x.multiplyTo(y,r); this.reduce(r); }
function cSqrTo(x,r) { x.squareTo(r); this.reduce(r); }

Classic.prototype.convert = cConvert;
Classic.prototype.revert = cRevert;
Classic.prototype.reduce = cReduce;
Classic.prototype.mulTo = cMulTo;
Classic.prototype.sqrTo = cSqrTo;

// (protected) return "-1/this % 2^DB"; useful for Mont. reduction
// justification:
//         xy == 1 (mod m)
//         xy =  1+km
//   xy(2-xy) = (1+km)(1-km)
// x[y(2-xy)] = 1-k^2m^2
// x[y(2-xy)] == 1 (mod m^2)
// if y is 1/x mod m, then y(2-xy) is 1/x mod m^2
// should reduce x and y(2-xy) by m^2 at each step to keep size bounded.
// JS multiply "overflows" differently from C/C++, so care is needed here.
function bnpInvDigit() {
  if(this.t < 1) return 0;
  var x = this[0];
  if((x&1) == 0) return 0;
  var y = x&3;		// y == 1/x mod 2^2
  y = (y*(2-(x&0xf)*y))&0xf;	// y == 1/x mod 2^4
  y = (y*(2-(x&0xff)*y))&0xff;	// y == 1/x mod 2^8
  y = (y*(2-(((x&0xffff)*y)&0xffff)))&0xffff;	// y == 1/x mod 2^16
  // last step - calculate inverse mod DV directly;
  // assumes 16 < DB <= 32 and assumes ability to handle 48-bit ints
  y = (y*(2-x*y%this.DV))%this.DV;		// y == 1/x mod 2^dbits
  // we really want the negative inverse, and -DV < y < DV
  return (y>0)?this.DV-y:-y;
}

// Montgomery reduction
function Montgomery(m) {
  this.m = m;
  this.mp = m.invDigit();
  this.mpl = this.mp&0x7fff;
  this.mph = this.mp>>15;
  this.um = (1<<(m.DB-15))-1;
  this.mt2 = 2*m.t;
}

// xR mod m
function montConvert(x) {
  var r = nbi();
  x.abs().dlShiftTo(this.m.t,r);
  r.divRemTo(this.m,null,r);
  if(x.s < 0 && r.compareTo(BigInteger.ZERO) > 0) this.m.subTo(r,r);
  return r;
}

// x/R mod m
function montRevert(x) {
  var r = nbi();
  x.copyTo(r);
  this.reduce(r);
  return r;
}

// x = x/R mod m (HAC 14.32)
function montReduce(x) {
  while(x.t <= this.mt2)	// pad x so am has enough room later
    x[x.t++] = 0;
  for(var i = 0; i < this.m.t; ++i) {
    // faster way of calculating u0 = x[i]*mp mod DV
    var j = x[i]&0x7fff;
    var u0 = (j*this.mpl+(((j*this.mph+(x[i]>>15)*this.mpl)&this.um)<<15))&x.DM;
    // use am to combine the multiply-shift-add into one call
    j = i+this.m.t;
    x[j] += this.m.am(0,u0,x,i,0,this.m.t);
    // propagate carry
    while(x[j] >= x.DV) { x[j] -= x.DV; x[++j]++; }
  }
  x.clamp();
  x.drShiftTo(this.m.t,x);
  if(x.compareTo(this.m) >= 0) x.subTo(this.m,x);
}

// r = "x^2/R mod m"; x != r
function montSqrTo(x,r) { x.squareTo(r); this.reduce(r); }

// r = "xy/R mod m"; x,y != r
function montMulTo(x,y,r) { x.multiplyTo(y,r); this.reduce(r); }

Montgomery.prototype.convert = montConvert;
Montgomery.prototype.revert = montRevert;
Montgomery.prototype.reduce = montReduce;
Montgomery.prototype.mulTo = montMulTo;
Montgomery.prototype.sqrTo = montSqrTo;

// (protected) true iff this is even
function bnpIsEven() { return ((this.t>0)?(this[0]&1):this.s) == 0; }

// (protected) this^e, e < 2^32, doing sqr and mul with "r" (HAC 14.79)
function bnpExp(e,z) {
  if(e > 0xffffffff || e < 1) return BigInteger.ONE;
  var r = nbi(), r2 = nbi(), g = z.convert(this), i = nbits(e)-1;
  g.copyTo(r);
  while(--i >= 0) {
    z.sqrTo(r,r2);
    if((e&(1<<i)) > 0) z.mulTo(r2,g,r);
    else { var t = r; r = r2; r2 = t; }
  }
  return z.revert(r);
}

// (public) this^e % m, 0 <= e < 2^32
function bnModPowInt(e,m) {
  var z;
  if(e < 256 || m.isEven()) z = new Classic(m); else z = new Montgomery(m);
  return this.exp(e,z);
}

// protected
BigInteger.prototype.copyTo = bnpCopyTo;
BigInteger.prototype.fromInt = bnpFromInt;
BigInteger.prototype.fromString = bnpFromString;
BigInteger.prototype.clamp = bnpClamp;
BigInteger.prototype.dlShiftTo = bnpDLShiftTo;
BigInteger.prototype.drShiftTo = bnpDRShiftTo;
BigInteger.prototype.lShiftTo = bnpLShiftTo;
BigInteger.prototype.rShiftTo = bnpRShiftTo;
BigInteger.prototype.subTo = bnpSubTo;
BigInteger.prototype.multiplyTo = bnpMultiplyTo;
BigInteger.prototype.squareTo = bnpSquareTo;
BigInteger.prototype.divRemTo = bnpDivRemTo;
BigInteger.prototype.invDigit = bnpInvDigit;
BigInteger.prototype.isEven = bnpIsEven;
BigInteger.prototype.exp = bnpExp;

// public
BigInteger.prototype.toString = bnToString;
BigInteger.prototype.negate = bnNegate;
BigInteger.prototype.abs = bnAbs;
BigInteger.prototype.compareTo = bnCompareTo;
BigInteger.prototype.bitLength = bnBitLength;
BigInteger.prototype.mod = bnMod;
BigInteger.prototype.modPowInt = bnModPowInt;

// "constants"
BigInteger.ZERO = nbv(0);
BigInteger.ONE = nbv(1);

return module.exports;
};

require.modules["matcher"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview Matcher class implementing matching addresses against
 *               a list of filters.
 */

const {Filter, WhitelistFilter} = require("filterClasses");

/**
 * Blacklist/whitelist filter matching
 * @constructor
 */
function Matcher()
{
  this.clear();
}
exports.Matcher = Matcher;

Matcher.prototype = {
  /**
   * Lookup table for filters by their associated keyword
   * @type {Object}
   */
  filterByKeyword: null,

  /**
   * Lookup table for keywords by the filter text
   * @type {Object}
   */
  keywordByFilter: null,

  /**
   * Removes all known filters
   */
  clear()
  {
    this.filterByKeyword = Object.create(null);
    this.keywordByFilter = Object.create(null);
  },

  /**
   * Adds a filter to the matcher
   * @param {RegExpFilter} filter
   */
  add(filter)
  {
    if (filter.text in this.keywordByFilter)
      return;

    // Look for a suitable keyword
    let keyword = this.findKeyword(filter);
    let oldEntry = this.filterByKeyword[keyword];
    if (typeof oldEntry == "undefined")
      this.filterByKeyword[keyword] = filter;
    else if (oldEntry.length == 1)
      this.filterByKeyword[keyword] = [oldEntry, filter];
    else
      oldEntry.push(filter);
    this.keywordByFilter[filter.text] = keyword;
  },

  /**
   * Removes a filter from the matcher
   * @param {RegExpFilter} filter
   */
  remove(filter)
  {
    if (!(filter.text in this.keywordByFilter))
      return;

    let keyword = this.keywordByFilter[filter.text];
    let list = this.filterByKeyword[keyword];
    if (list.length <= 1)
      delete this.filterByKeyword[keyword];
    else
    {
      let index = list.indexOf(filter);
      if (index >= 0)
      {
        list.splice(index, 1);
        if (list.length == 1)
          this.filterByKeyword[keyword] = list[0];
      }
    }

    delete this.keywordByFilter[filter.text];
  },

  /**
   * Chooses a keyword to be associated with the filter
   * @param {Filter} filter
   * @return {string} keyword or an empty string if no keyword could be found
   */
  findKeyword(filter)
  {
    let result = "";
    let {text} = filter;
    if (Filter.regexpRegExp.test(text))
      return result;

    // Remove options
    let match = Filter.optionsRegExp.exec(text);
    if (match)
      text = match.input.substr(0, match.index);

    // Remove whitelist marker
    if (text.substr(0, 2) == "@@")
      text = text.substr(2);

    let candidates = text.toLowerCase().match(
      /[^a-z0-9%*][a-z0-9%]{3,}(?=[^a-z0-9%*])/g
    );
    if (!candidates)
      return result;

    let hash = this.filterByKeyword;
    let resultCount = 0xFFFFFF;
    let resultLength = 0;
    for (let i = 0, l = candidates.length; i < l; i++)
    {
      let candidate = candidates[i].substr(1);
      let count = (candidate in hash ? hash[candidate].length : 0);
      if (count < resultCount ||
          (count == resultCount && candidate.length > resultLength))
      {
        result = candidate;
        resultCount = count;
        resultLength = candidate.length;
      }
    }
    return result;
  },

  /**
   * Checks whether a particular filter is being matched against.
   * @param {RegExpFilter} filter
   * @return {boolean}
   */
  hasFilter(filter)
  {
    return (filter.text in this.keywordByFilter);
  },

  /**
   * Returns the keyword used for a filter, null for unknown filters.
   * @param {RegExpFilter} filter
   * @return {string}
   */
  getKeywordForFilter(filter)
  {
    if (filter.text in this.keywordByFilter)
      return this.keywordByFilter[filter.text];
    return null;
  },

  /**
   * Checks whether the entries for a particular keyword match a URL
   * @param {string} keyword
   * @param {string} location
   * @param {number} typeMask
   * @param {string} docDomain
   * @param {boolean} thirdParty
   * @param {string} sitekey
   * @param {boolean} specificOnly
   * @return {?Filter}
   */
  _checkEntryMatch(keyword, location, typeMask, docDomain, thirdParty, sitekey,
                   specificOnly)
  {
    let list = this.filterByKeyword[keyword];
    for (let i = 0; i < list.length; i++)
    {
      let filter = list[i];

      if (specificOnly && filter.isGeneric() &&
          !(filter instanceof WhitelistFilter))
        continue;

      if (filter.matches(location, typeMask, docDomain, thirdParty, sitekey))
        return filter;
    }
    return null;
  },

  /**
   * Tests whether the URL matches any of the known filters
   * @param {string} location
   *   URL to be tested
   * @param {number} typeMask
   *   bitmask of content / request types to match
   * @param {string} docDomain
   *   domain name of the document that loads the URL
   * @param {boolean} thirdParty
   *   should be true if the URL is a third-party request
   * @param {string} sitekey
   *   public key provided by the document
   * @param {boolean} specificOnly
   *   should be true if generic matches should be ignored
   * @return {?RegExpFilter}
   *   matching filter or null
   */
  matchesAny(location, typeMask, docDomain, thirdParty, sitekey, specificOnly)
  {
    let candidates = location.toLowerCase().match(/[a-z0-9%]{3,}/g);
    if (candidates === null)
      candidates = [];
    candidates.push("");
    for (let i = 0, l = candidates.length; i < l; i++)
    {
      let substr = candidates[i];
      if (substr in this.filterByKeyword)
      {
        let result = this._checkEntryMatch(substr, location, typeMask,
                                           docDomain, thirdParty, sitekey,
                                           specificOnly);
        if (result)
          return result;
      }
    }

    return null;
  }
};

/**
 * Combines a matcher for blocking and exception rules, automatically sorts
 * rules into two Matcher instances.
 * @constructor
 * @augments Matcher
 */
function CombinedMatcher()
{
  this.blacklist = new Matcher();
  this.whitelist = new Matcher();
  this.resultCache = Object.create(null);
}
exports.CombinedMatcher = CombinedMatcher;

/**
 * Maximal number of matching cache entries to be kept
 * @type {number}
 */
CombinedMatcher.maxCacheEntries = 1000;

CombinedMatcher.prototype =
{
  /**
   * Matcher for blocking rules.
   * @type {Matcher}
   */
  blacklist: null,

  /**
   * Matcher for exception rules.
   * @type {Matcher}
   */
  whitelist: null,

  /**
   * Lookup table of previous matchesAny results
   * @type {Object}
   */
  resultCache: null,

  /**
   * Number of entries in resultCache
   * @type {number}
   */
  cacheEntries: 0,

  /**
   * @see Matcher#clear
   */
  clear()
  {
    this.blacklist.clear();
    this.whitelist.clear();
    this.resultCache = Object.create(null);
    this.cacheEntries = 0;
  },

  /**
   * @see Matcher#add
   * @param {Filter} filter
   */
  add(filter)
  {
    if (filter instanceof WhitelistFilter)
      this.whitelist.add(filter);
    else
      this.blacklist.add(filter);

    if (this.cacheEntries > 0)
    {
      this.resultCache = Object.create(null);
      this.cacheEntries = 0;
    }
  },

  /**
   * @see Matcher#remove
   * @param {Filter} filter
   */
  remove(filter)
  {
    if (filter instanceof WhitelistFilter)
      this.whitelist.remove(filter);
    else
      this.blacklist.remove(filter);

    if (this.cacheEntries > 0)
    {
      this.resultCache = Object.create(null);
      this.cacheEntries = 0;
    }
  },

  /**
   * @see Matcher#findKeyword
   * @param {Filter} filter
   * @return {string} keyword
   */
  findKeyword(filter)
  {
    if (filter instanceof WhitelistFilter)
      return this.whitelist.findKeyword(filter);
    return this.blacklist.findKeyword(filter);
  },

  /**
   * @see Matcher#hasFilter
   * @param {Filter} filter
   * @return {boolean}
   */
  hasFilter(filter)
  {
    if (filter instanceof WhitelistFilter)
      return this.whitelist.hasFilter(filter);
    return this.blacklist.hasFilter(filter);
  },

  /**
   * @see Matcher#getKeywordForFilter
   * @param {Filter} filter
   * @return {string} keyword
   */
  getKeywordForFilter(filter)
  {
    if (filter instanceof WhitelistFilter)
      return this.whitelist.getKeywordForFilter(filter);
    return this.blacklist.getKeywordForFilter(filter);
  },

  /**
   * Checks whether a particular filter is slow
   * @param {RegExpFilter} filter
   * @return {boolean}
   */
  isSlowFilter(filter)
  {
    let matcher = (
      filter instanceof WhitelistFilter ? this.whitelist : this.blacklist
    );
    if (matcher.hasFilter(filter))
      return !matcher.getKeywordForFilter(filter);
    return !matcher.findKeyword(filter);
  },

  /**
   * Optimized filter matching testing both whitelist and blacklist matchers
   * simultaneously. For parameters see Matcher.matchesAny().
   * @see Matcher#matchesAny
   * @inheritdoc
   */
  matchesAnyInternal(location, typeMask, docDomain, thirdParty, sitekey,
                     specificOnly)
  {
    let candidates = location.toLowerCase().match(/[a-z0-9%]{3,}/g);
    if (candidates === null)
      candidates = [];
    candidates.push("");

    let blacklistHit = null;
    for (let i = 0, l = candidates.length; i < l; i++)
    {
      let substr = candidates[i];
      if (substr in this.whitelist.filterByKeyword)
      {
        let result = this.whitelist._checkEntryMatch(
          substr, location, typeMask, docDomain, thirdParty, sitekey
        );
        if (result)
          return result;
      }
      if (substr in this.blacklist.filterByKeyword && blacklistHit === null)
      {
        blacklistHit = this.blacklist._checkEntryMatch(
          substr, location, typeMask, docDomain, thirdParty, sitekey,
          specificOnly
        );
      }
    }
    return blacklistHit;
  },

  /**
   * @see Matcher#matchesAny
   * @inheritdoc
   */
  matchesAny(location, typeMask, docDomain, thirdParty, sitekey, specificOnly)
  {
    let key = location + " " + typeMask + " " + docDomain + " " + thirdParty +
      " " + sitekey + " " + specificOnly;
    if (key in this.resultCache)
      return this.resultCache[key];

    let result = this.matchesAnyInternal(location, typeMask, docDomain,
                                         thirdParty, sitekey, specificOnly);

    if (this.cacheEntries >= CombinedMatcher.maxCacheEntries)
    {
      this.resultCache = Object.create(null);
      this.cacheEntries = 0;
    }

    this.resultCache[key] = result;
    this.cacheEntries++;

    return result;
  }
};

/**
 * Shared CombinedMatcher instance that should usually be used.
 * @type {CombinedMatcher}
 */
exports.defaultMatcher = new CombinedMatcher();

return module.exports;
};

require.modules["notification"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview Handles notifications.
 */

const {Services} = Cu.import("resource://gre/modules/Services.jsm", {});

const {Prefs} = require("prefs");
const {Downloader, Downloadable,
       MILLIS_IN_MINUTE, MILLIS_IN_HOUR, MILLIS_IN_DAY} = require("downloader");
const {Utils} = require("utils");
const {Matcher, defaultMatcher} = require("matcher");
const {Filter, RegExpFilter, WhitelistFilter} = require("filterClasses");

const INITIAL_DELAY = 1 * MILLIS_IN_MINUTE;
const CHECK_INTERVAL = 1 * MILLIS_IN_HOUR;
const EXPIRATION_INTERVAL = 1 * MILLIS_IN_DAY;
const TYPE = {
  information: 0,
  question: 1,
  relentless: 2,
  critical: 3
};

let showListeners = [];
let questionListeners = {};

function getNumericalSeverity(notification)
{
  if (notification.type in TYPE)
    return TYPE[notification.type];
  return TYPE.information;
}

function saveNotificationData()
{
  // HACK: JSON values aren't saved unless they are assigned a different object.
  Prefs.notificationdata = JSON.parse(JSON.stringify(Prefs.notificationdata));
}

function localize(translations, locale)
{
  if (locale in translations)
    return translations[locale];

  let languagePart = locale.substring(0, locale.indexOf("-"));
  if (languagePart && languagePart in translations)
    return translations[languagePart];

  let defaultLocale = "en-US";
  return translations[defaultLocale];
}

/**
 * The object providing actual downloading functionality.
 * @type {Downloader}
 */
let downloader = null;
let localData = [];

/**
 * Regularly fetches notifications and decides which to show.
 * @class
 */
let Notification = exports.Notification =
{
  /**
   * Called on module startup.
   */
  init()
  {
    downloader = new Downloader(this._getDownloadables.bind(this),
                                INITIAL_DELAY, CHECK_INTERVAL);
    downloader.onExpirationChange = this._onExpirationChange.bind(this);
    downloader.onDownloadSuccess = this._onDownloadSuccess.bind(this);
    downloader.onDownloadError = this._onDownloadError.bind(this);
    onShutdown.add(() => downloader.cancel());
  },

  /**
   * Yields a Downloadable instances for the notifications download.
   */
  *_getDownloadables()
  {
    let downloadable = new Downloadable(Prefs.notificationurl);
    if (typeof Prefs.notificationdata.lastError === "number")
      downloadable.lastError = Prefs.notificationdata.lastError;
    if (typeof Prefs.notificationdata.lastCheck === "number")
      downloadable.lastCheck = Prefs.notificationdata.lastCheck;
    if (typeof Prefs.notificationdata.data === "object" &&
        "version" in Prefs.notificationdata.data)
    {
      downloadable.lastVersion = Prefs.notificationdata.data.version;
    }
    if (typeof Prefs.notificationdata.softExpiration === "number")
      downloadable.softExpiration = Prefs.notificationdata.softExpiration;
    if (typeof Prefs.notificationdata.hardExpiration === "number")
      downloadable.hardExpiration = Prefs.notificationdata.hardExpiration;
    if (typeof Prefs.notificationdata.downloadCount === "number")
      downloadable.downloadCount = Prefs.notificationdata.downloadCount;
    yield downloadable;
  },

  _onExpirationChange(downloadable)
  {
    Prefs.notificationdata.lastCheck = downloadable.lastCheck;
    Prefs.notificationdata.softExpiration = downloadable.softExpiration;
    Prefs.notificationdata.hardExpiration = downloadable.hardExpiration;
    saveNotificationData();
  },

  _onDownloadSuccess(downloadable, responseText, errorCallback,
                     redirectCallback)
  {
    try
    {
      let data = JSON.parse(responseText);
      for (let notification of data.notifications)
      {
        if ("severity" in notification)
        {
          if (!("type" in notification))
            notification.type = notification.severity;
          delete notification.severity;
        }
      }
      Prefs.notificationdata.data = data;
    }
    catch (e)
    {
      Cu.reportError(e);
      errorCallback("synchronize_invalid_data");
      return;
    }

    Prefs.notificationdata.lastError = 0;
    Prefs.notificationdata.downloadStatus = "synchronize_ok";
    [
      Prefs.notificationdata.softExpiration,
      Prefs.notificationdata.hardExpiration
    ] = downloader.processExpirationInterval(EXPIRATION_INTERVAL);
    Prefs.notificationdata.downloadCount = downloadable.downloadCount;
    saveNotificationData();

    Notification.showNext();
  },

  _onDownloadError(downloadable, downloadURL, error, channelStatus,
                   responseStatus, redirectCallback)
  {
    Prefs.notificationdata.lastError = Date.now();
    Prefs.notificationdata.downloadStatus = error;
    saveNotificationData();
  },

  /**
   * Adds a listener for notifications to be shown.
   * @param {Function} listener Listener to be invoked when a notification is
   *                   to be shown
   */
  addShowListener(listener)
  {
    if (showListeners.indexOf(listener) == -1)
      showListeners.push(listener);
  },

  /**
   * Removes the supplied listener.
   * @param {Function} listener Listener that was added via addShowListener()
   */
  removeShowListener(listener)
  {
    let index = showListeners.indexOf(listener);
    if (index != -1)
      showListeners.splice(index, 1);
  },

  /**
   * Determines which notification is to be shown next.
   * @param {string} url URL to match notifications to (optional)
   * @return {Object} notification to be shown, or null if there is none
   */
  _getNextToShow(url)
  {
    let remoteData = [];
    if (typeof Prefs.notificationdata.data == "object" &&
        Prefs.notificationdata.data.notifications instanceof Array)
    {
      remoteData = Prefs.notificationdata.data.notifications;
    }

    let notifications = localData.concat(remoteData);
    if (notifications.length === 0)
      return null;

    const {addonName, addonVersion, application,
           applicationVersion, platform, platformVersion} = require("info");

    let targetChecks = {
      extension: v => v == addonName,
      extensionMinVersion:
        v => Services.vc.compare(addonVersion, v) >= 0,
      extensionMaxVersion:
        v => Services.vc.compare(addonVersion, v) <= 0,
      application: v => v == application,
      applicationMinVersion:
        v => Services.vc.compare(applicationVersion, v) >= 0,
      applicationMaxVersion:
        v => Services.vc.compare(applicationVersion, v) <= 0,
      platform: v => v == platform,
      platformMinVersion:
        v => Services.vc.compare(platformVersion, v) >= 0,
      platformMaxVersion:
        v => Services.vc.compare(platformVersion, v) <= 0,
      blockedTotalMin: v => Prefs.show_statsinpopup &&
        Prefs.blocked_total >= v,
      blockedTotalMax: v => Prefs.show_statsinpopup &&
        Prefs.blocked_total <= v,
      locales: v => v.includes(Utils.appLocale)
    };

    let notificationToShow = null;
    for (let notification of notifications)
    {
      if (typeof notification.type === "undefined" ||
          notification.type !== "critical")
      {
        let shown;
        if (typeof Prefs.notificationdata.shown == "object")
          shown = Prefs.notificationdata.shown[notification.id];

        if (typeof shown != "undefined")
        {
          if (typeof notification.interval == "number")
          {
            if (shown + notification.interval > Date.now())
              continue;
          }
          else if (shown)
            continue;
        }

        if (notification.type !== "relentless" &&
            Prefs.notifications_ignoredcategories.indexOf("*") != -1)
        {
          continue;
        }
      }

      if (typeof url === "string" || notification.urlFilters instanceof Array)
      {
        if (Prefs.enabled && typeof url === "string" &&
            notification.urlFilters instanceof Array)
        {
          let host;
          try
          {
            host = new URL(url).hostname;
          }
          catch (e)
          {
            host = "";
          }

          let exception = defaultMatcher.matchesAny(
            url, RegExpFilter.typeMap.DOCUMENT, host, false, null
          );
          if (exception instanceof WhitelistFilter)
            continue;

          let matcher = new Matcher();
          for (let urlFilter of notification.urlFilters)
            matcher.add(Filter.fromText(urlFilter));
          if (!matcher.matchesAny(url, RegExpFilter.typeMap.DOCUMENT, host,
              false, null))
          {
            continue;
          }
        }
        else
          continue;
      }

      if (notification.targets instanceof Array)
      {
        let match = false;

        for (let target of notification.targets)
        {
          if (Object.keys(target).every(key =>
              targetChecks.hasOwnProperty(key) &&
              targetChecks[key](target[key])))
          {
            match = true;
            break;
          }
        }
        if (!match)
        {
          continue;
        }
      }

      if (!notificationToShow ||
          getNumericalSeverity(notification) >
            getNumericalSeverity(notificationToShow))
        notificationToShow = notification;
    }

    return notificationToShow;
  },

  /**
   * Invokes the listeners added via addShowListener() with the next
   * notification to be shown.
   * @param {string} url URL to match notifications to (optional)
   */
  showNext(url)
  {
    let notification = Notification._getNextToShow(url);
    if (notification)
    {
      for (let showListener of showListeners)
        showListener(notification);
    }
  },

  /**
   * Marks a notification as shown.
   * @param {string} id ID of the notification to be marked as shown
   */
  markAsShown(id)
  {
    let now = Date.now();
    let data = Prefs.notificationdata;

    if (data.shown instanceof Array)
    {
      let newShown = {};
      for (let oldId of data.shown)
        newShown[oldId] = now;
      data.shown = newShown;
    }

    if (typeof data.shown != "object")
      data.shown = {};

    data.shown[id] = now;

    saveNotificationData();
  },

  /**
   * Localizes the texts of the supplied notification.
   * @param {Object} notification notification to translate
   * @param {string} locale the target locale (optional, defaults to the
   *                        application locale)
   * @return {Object} the translated texts
   */
  getLocalizedTexts(notification, locale)
  {
    locale = locale || Utils.appLocale;
    let textKeys = ["title", "message"];
    let localizedTexts = [];
    for (let key of textKeys)
    {
      if (key in notification)
      {
        if (typeof notification[key] == "string")
          localizedTexts[key] = notification[key];
        else
          localizedTexts[key] = localize(notification[key], locale);
      }
    }
    return localizedTexts;
  },

  /**
   * Adds a local notification.
   * @param {Object} notification notification to add
   */
  addNotification(notification)
  {
    if (localData.indexOf(notification) == -1)
      localData.push(notification);
  },

  /**
   * Removes an existing local notification.
   * @param {Object} notification notification to remove
   */
  removeNotification(notification)
  {
    let index = localData.indexOf(notification);
    if (index > -1)
      localData.splice(index, 1);
  },

  /**
   * A callback function which listens to see if notifications were approved.
   *
   * @callback QuestionListener
   * @param {boolean} approved
   */

  /**
   * Adds a listener for question-type notifications
   * @param {string} id
   * @param {QuestionListener} listener
   */
  addQuestionListener(id, listener)
  {
    if (!(id in questionListeners))
      questionListeners[id] = [];
    if (questionListeners[id].indexOf(listener) === -1)
      questionListeners[id].push(listener);
  },

  /**
   * Removes a listener that was previously added via addQuestionListener
   * @param {string} id
   * @param {QuestionListener} listener
   */
  removeQuestionListener(id, listener)
  {
    if (!(id in questionListeners))
      return;
    let index = questionListeners[id].indexOf(listener);
    if (index > -1)
      questionListeners[id].splice(index, 1);
    if (questionListeners[id].length === 0)
      delete questionListeners[id];
  },

  /**
   * Notifies question listeners about interactions with a notification
   * @param {string} id notification ID
   * @param {boolean} approved indicator whether notification has been approved
   */
  triggerQuestionListeners(id, approved)
  {
    if (!(id in questionListeners))
      return;
    let listeners = questionListeners[id];
    for (let listener of listeners)
      listener(approved);
  },

  /**
   * Toggles whether notifications of a specific category should be ignored
   * @param {string} category notification category identifier
   * @param {boolean} [forceValue] force specified value
   */
  toggleIgnoreCategory(category, forceValue)
  {
    let categories = Prefs.notifications_ignoredcategories;
    let index = categories.indexOf(category);
    if (index == -1 && forceValue !== false)
    {
      categories.push(category);
      Prefs.notifications_showui = true;
    }
    else if (index != -1 && forceValue !== true)
      categories.splice(index, 1);

    // HACK: JSON values aren't saved unless they are assigned a
    // different object.
    Prefs.notifications_ignoredcategories =
      JSON.parse(JSON.stringify(categories));
  }
};
Notification.init();

return module.exports;
};

require.modules["rsa"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

/* global console */

"use strict";

/**
 * This is a specialized RSA library meant only to verify SHA1-based signatures.
 */

const {BigInteger} = require("jsbn");
const Rusha = require("rusha");

let rusha = new Rusha();

// Define ASN.1 templates for the data structures used
function seq(...args)
{
  return {type: 0x30, children: args};
}
function obj(id)
{
  return {type: 0x06, content: id};
}
function bitStr(contents)
{
  return {type: 0x03, encapsulates: contents};
}
function intResult(id)
{
  return {type: 0x02, out: id};
}
function octetResult(id)
{
  return {type: 0x04, out: id};
}

// See http://www.cryptopp.com/wiki/Keys_and_Formats#RSA_PublicKey
// 2A 86 48 86 F7 0D 01 01 01 means 1.2.840.113549.1.1.1
let publicKeyTemplate = seq(
  seq(obj("\x2A\x86\x48\x86\xF7\x0D\x01\x01\x01"), {}),
  bitStr(seq(intResult("n"), intResult("e")))
);

// See http://tools.ietf.org/html/rfc3447#section-9.2 step 2
// 2B 0E 03 02 1A means 1.3.14.3.2.26
let signatureTemplate = seq(
  seq(obj("\x2B\x0E\x03\x02\x1A"), {}),
  octetResult("sha1")
);

/**
 * Reads ASN.1 data matching the template passed in. This will throw an
 * exception if the data format doesn't match the template. On success an
 * object containing result properties is returned.
 * @see http://luca.ntop.org/Teaching/Appunti/asn1.html for info on the format.
 * @param {string} data
 * @param {Object} templ
 * @returns {Object}
 */
function readASN1(data, templ)
{
  let pos = 0;
  function next()
  {
    return data.charCodeAt(pos++);
  }

  function readLength()
  {
    let len = next();
    if (len & 0x80)
    {
      let cnt = len & 0x7F;
      if (cnt > 2 || cnt == 0)
        throw "Unsupported length";

      len = 0;
      for (let i = 0; i < cnt; i++)
        len += next() << (cnt - 1 - i) * 8;
      return len;
    }
    return len;
  }

  function readNode(curTempl)
  {
    let type = next();
    let len = readLength();
    if ("type" in curTempl && curTempl.type != type)
      throw "Unexpected type";
    if ("content" in curTempl && curTempl.content != data.substr(pos, len))
      throw "Unexpected content";
    if ("out" in curTempl)
      out[curTempl.out] = new BigInteger(data.substr(pos, len), 256);
    if ("children" in curTempl)
    {
      let i;
      let end;
      for (i = 0, end = pos + len; pos < end; i++)
      {
        if (i >= curTempl.children.length)
          throw "Too many children";
        readNode(curTempl.children[i]);
      }
      if (i < curTempl.children.length)
        throw "Too few children";
      if (pos > end)
        throw "Children too large";
    }
    else if ("encapsulates" in curTempl)
    {
      if (next() != 0)
        throw "Encapsulation expected";
      readNode(curTempl.encapsulates);
    }
    else
      pos += len;
  }

  let out = {};
  readNode(templ);
  if (pos != data.length)
    throw "Too much data";
  return out;
}

/**
 * Reads a BER-encoded RSA public key. On success returns an object with the
 * properties n and e (the components of the key), otherwise null.
 * @param {string} key
 * @return {?Object}
 */
function readPublicKey(key)
{
  try
  {
    return readASN1(atob(key), publicKeyTemplate);
  }
  catch (e)
  {
    console.warn("Invalid RSA public key: " + e);
    return null;
  }
}

/**
 * Checks whether the signature is valid for the given public key and data.
 * @param {string} key
 * @param {string} signature
 * @param {string} data
 * @return {boolean}
 */
function verifySignature(key, signature, data)
{
  let keyData = readPublicKey(key);
  if (!keyData)
    return false;

  // We need the exponent as regular number
  keyData.e = parseInt(keyData.e.toString(16), 16);

  // Decrypt signature data using RSA algorithm
  let sigInt = new BigInteger(atob(signature), 256);
  let digest = sigInt.modPowInt(keyData.e, keyData.n).toString(256);

  try
  {
    let pos = 0;
    let next = () => digest.charCodeAt(pos++);

    // Skip padding, see http://tools.ietf.org/html/rfc3447#section-9.2 step 5
    if (next() != 1)
      throw "Wrong padding in signature digest";
    while (next() == 255) {}
    if (digest.charCodeAt(pos - 1) != 0)
      throw "Wrong padding in signature digest";

    // Rest is an ASN.1 structure, get the SHA1 hash from it and compare to
    // the real one
    let {sha1} = readASN1(digest.substr(pos), signatureTemplate);
    let expected = new BigInteger(rusha.digest(data), 16);
    return (sha1.compareTo(expected) == 0);
  }
  catch (e)
  {
    console.warn("Invalid encrypted signature: " + e);
    return false;
  }
}
exports.verifySignature = verifySignature;

return module.exports;
};

require.modules["rusha"] = function(module, exports)
{
(function () {
    var /*
 * Rusha, a JavaScript implementation of the Secure Hash Algorithm, SHA-1,
 * as defined in FIPS PUB 180-1, tuned for high performance with large inputs.
 * (http://github.com/srijs/rusha)
 *
 * Inspired by Paul Johnstons implementation (http://pajhome.org.uk/crypt/md5).
 *
 * Copyright (c) 2013 Sam Rijs (http://awesam.de).
 * Released under the terms of the MIT license as follows:
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */
    util = {
        getDataType: function (data) {
            if (typeof data === 'string') {
                return 'string';
            }
            if (data instanceof Array) {
                return 'array';
            }
            if (typeof global !== 'undefined' && global.Buffer && global.Buffer.isBuffer(data)) {
                return 'buffer';
            }
            if (data instanceof ArrayBuffer) {
                return 'arraybuffer';
            }
            if (data.buffer instanceof ArrayBuffer) {
                return 'view';
            }
            if (data instanceof Blob) {
                return 'blob';
            }
            throw new Error('Unsupported data type.');
        }
    };
    function Rusha(chunkSize) {
        'use strict';
        var // Private object structure.
        self$2 = { fill: 0 };
        var // Calculate the length of buffer that the sha1 routine uses
        // including the padding.
        padlen = function (len) {
            for (len += 9; len % 64 > 0; len += 1);
            return len;
        };
        var padZeroes = function (bin, len) {
            for (var i$2 = len >> 2; i$2 < bin.length; i$2++)
                bin[i$2] = 0;
        };
        var padData = function (bin, chunkLen, msgLen) {
            bin[chunkLen >> 2] |= 128 << 24 - (chunkLen % 4 << 3);
            // To support msgLen >= 2 GiB, use a float division when computing the
            // high 32-bits of the big-endian message length in bits.
            bin[((chunkLen >> 2) + 2 & ~15) + 14] = msgLen / (1 << 29) | 0;
            bin[((chunkLen >> 2) + 2 & ~15) + 15] = msgLen << 3;
        };
        var // Convert a binary string and write it to the heap.
        // A binary string is expected to only contain char codes < 256.
        convStr = function (H8, H32, start, len, off) {
            var str = this, i$2, om = off % 4, lm = len % 4, j = len - lm;
            if (j > 0) {
                switch (om) {
                case 0:
                    H8[off + 3 | 0] = str.charCodeAt(start);
                case 1:
                    H8[off + 2 | 0] = str.charCodeAt(start + 1);
                case 2:
                    H8[off + 1 | 0] = str.charCodeAt(start + 2);
                case 3:
                    H8[off | 0] = str.charCodeAt(start + 3);
                }
            }
            for (i$2 = om; i$2 < j; i$2 = i$2 + 4 | 0) {
                H32[off + i$2 >> 2] = str.charCodeAt(start + i$2) << 24 | str.charCodeAt(start + i$2 + 1) << 16 | str.charCodeAt(start + i$2 + 2) << 8 | str.charCodeAt(start + i$2 + 3);
            }
            switch (lm) {
            case 3:
                H8[off + j + 1 | 0] = str.charCodeAt(start + j + 2);
            case 2:
                H8[off + j + 2 | 0] = str.charCodeAt(start + j + 1);
            case 1:
                H8[off + j + 3 | 0] = str.charCodeAt(start + j);
            }
        };
        var // Convert a buffer or array and write it to the heap.
        // The buffer or array is expected to only contain elements < 256.
        convBuf = function (H8, H32, start, len, off) {
            var buf = this, i$2, om = off % 4, lm = len % 4, j = len - lm;
            if (j > 0) {
                switch (om) {
                case 0:
                    H8[off + 3 | 0] = buf[start];
                case 1:
                    H8[off + 2 | 0] = buf[start + 1];
                case 2:
                    H8[off + 1 | 0] = buf[start + 2];
                case 3:
                    H8[off | 0] = buf[start + 3];
                }
            }
            for (i$2 = 4 - om; i$2 < j; i$2 = i$2 += 4 | 0) {
                H32[off + i$2 >> 2] = buf[start + i$2] << 24 | buf[start + i$2 + 1] << 16 | buf[start + i$2 + 2] << 8 | buf[start + i$2 + 3];
            }
            switch (lm) {
            case 3:
                H8[off + j + 1 | 0] = buf[start + j + 2];
            case 2:
                H8[off + j + 2 | 0] = buf[start + j + 1];
            case 1:
                H8[off + j + 3 | 0] = buf[start + j];
            }
        };
        var convBlob = function (H8, H32, start, len, off) {
            var blob = this, i$2, om = off % 4, lm = len % 4, j = len - lm;
            var buf = new Uint8Array(reader.readAsArrayBuffer(blob.slice(start, start + len)));
            if (j > 0) {
                switch (om) {
                case 0:
                    H8[off + 3 | 0] = buf[0];
                case 1:
                    H8[off + 2 | 0] = buf[1];
                case 2:
                    H8[off + 1 | 0] = buf[2];
                case 3:
                    H8[off | 0] = buf[3];
                }
            }
            for (i$2 = 4 - om; i$2 < j; i$2 = i$2 += 4 | 0) {
                H32[off + i$2 >> 2] = buf[i$2] << 24 | buf[i$2 + 1] << 16 | buf[i$2 + 2] << 8 | buf[i$2 + 3];
            }
            switch (lm) {
            case 3:
                H8[off + j + 1 | 0] = buf[j + 2];
            case 2:
                H8[off + j + 2 | 0] = buf[j + 1];
            case 1:
                H8[off + j + 3 | 0] = buf[j];
            }
        };
        var convFn = function (data) {
            switch (util.getDataType(data)) {
            case 'string':
                return convStr.bind(data);
            case 'array':
                return convBuf.bind(data);
            case 'buffer':
                return convBuf.bind(data);
            case 'arraybuffer':
                return convBuf.bind(new Uint8Array(data));
            case 'view':
                return convBuf.bind(new Uint8Array(data.buffer, data.byteOffset, data.byteLength));
            case 'blob':
                return convBlob.bind(data);
            }
        };
        var slice = function (data, offset) {
            switch (util.getDataType(data)) {
            case 'string':
                return data.slice(offset);
            case 'array':
                return data.slice(offset);
            case 'buffer':
                return data.slice(offset);
            case 'arraybuffer':
                return data.slice(offset);
            case 'view':
                return data.buffer.slice(offset);
            }
        };
        var // Precompute 00 - ff strings
        precomputedHex = new Array(256);
        for (var i = 0; i < 256; i++) {
            precomputedHex[i] = (i < 16 ? '0' : '') + i.toString(16);
        }
        var // Convert an ArrayBuffer into its hexadecimal string representation.
        hex = function (arrayBuffer) {
            var binarray = new Uint8Array(arrayBuffer);
            var res = new Array(arrayBuffer.byteLength);
            for (var i$2 = 0; i$2 < res.length; i$2++) {
                res[i$2] = precomputedHex[binarray[i$2]];
            }
            return res.join('');
        };
        var ceilHeapSize = function (v) {
            // The asm.js spec says:
            // The heap object's byteLength must be either
            // 2^n for n in [12, 24) or 2^24 * n for n ≥ 1.
            // Also, byteLengths smaller than 2^16 are deprecated.
            var p;
            if (// If v is smaller than 2^16, the smallest possible solution
                // is 2^16.
                v <= 65536)
                return 65536;
            if (// If v < 2^24, we round up to 2^n,
                // otherwise we round up to 2^24 * n.
                v < 16777216) {
                for (p = 1; p < v; p = p << 1);
            } else {
                for (p = 16777216; p < v; p += 16777216);
            }
            return p;
        };
        var // Initialize the internal data structures to a new capacity.
        init = function (size) {
            if (size % 64 > 0) {
                throw new Error('Chunk size must be a multiple of 128 bit');
            }
            self$2.maxChunkLen = size;
            self$2.padMaxChunkLen = padlen(size);
            // The size of the heap is the sum of:
            // 1. The padded input message size
            // 2. The extended space the algorithm needs (320 byte)
            // 3. The 160 bit state the algoritm uses
            self$2.heap = new ArrayBuffer(ceilHeapSize(self$2.padMaxChunkLen + 320 + 20));
            self$2.h32 = new Int32Array(self$2.heap);
            self$2.h8 = new Int8Array(self$2.heap);
            self$2.core = new Rusha._core({
                Int32Array: Int32Array,
                DataView: DataView
            }, {}, self$2.heap);
            self$2.buffer = null;
        };
        // Iinitializethe datastructures according
        // to a chunk siyze.
        init(chunkSize || 64 * 1024);
        var initState = function (heap, padMsgLen) {
            var io = new Int32Array(heap, padMsgLen + 320, 5);
            io[0] = 1732584193;
            io[1] = -271733879;
            io[2] = -1732584194;
            io[3] = 271733878;
            io[4] = -1009589776;
        };
        var padChunk = function (chunkLen, msgLen) {
            var padChunkLen = padlen(chunkLen);
            var view = new Int32Array(self$2.heap, 0, padChunkLen >> 2);
            padZeroes(view, chunkLen);
            padData(view, chunkLen, msgLen);
            return padChunkLen;
        };
        var // Write data to the heap.
        write = function (data, chunkOffset, chunkLen) {
            convFn(data)(self$2.h8, self$2.h32, chunkOffset, chunkLen, 0);
        };
        var // Initialize and call the RushaCore,
        // assuming an input buffer of length len * 4.
        coreCall = function (data, chunkOffset, chunkLen, msgLen, finalize) {
            var padChunkLen = chunkLen;
            if (finalize) {
                padChunkLen = padChunk(chunkLen, msgLen);
            }
            write(data, chunkOffset, chunkLen);
            self$2.core.hash(padChunkLen, self$2.padMaxChunkLen);
        };
        var getRawDigest = function (heap, padMaxChunkLen) {
            var io = new Int32Array(heap, padMaxChunkLen + 320, 5);
            var out = new Int32Array(5);
            var arr = new DataView(out.buffer);
            arr.setInt32(0, io[0], false);
            arr.setInt32(4, io[1], false);
            arr.setInt32(8, io[2], false);
            arr.setInt32(12, io[3], false);
            arr.setInt32(16, io[4], false);
            return out;
        };
        var // Calculate the hash digest as an array of 5 32bit integers.
        rawDigest = this.rawDigest = function (str) {
            var msgLen = str.byteLength || str.length || str.size || 0;
            initState(self$2.heap, self$2.padMaxChunkLen);
            var chunkOffset = 0, chunkLen = self$2.maxChunkLen, last;
            for (chunkOffset = 0; msgLen > chunkOffset + chunkLen; chunkOffset += chunkLen) {
                coreCall(str, chunkOffset, chunkLen, msgLen, false);
            }
            coreCall(str, chunkOffset, msgLen - chunkOffset, msgLen, true);
            return getRawDigest(self$2.heap, self$2.padMaxChunkLen);
        };
        // The digest and digestFrom* interface returns the hash digest
        // as a hex string.
        this.digest = this.digestFromString = this.digestFromBuffer = this.digestFromArrayBuffer = function (str) {
            return hex(rawDigest(str).buffer);
        };
    }
    ;
    // The low-level RushCore module provides the heart of Rusha,
    // a high-speed sha1 implementation working on an Int32Array heap.
    // At first glance, the implementation seems complicated, however
    // with the SHA1 spec at hand, it is obvious this almost a textbook
    // implementation that has a few functions hand-inlined and a few loops
    // hand-unrolled.
    Rusha._core = function RushaCore(stdlib, foreign, heap) {
        'use asm';
        var H = new stdlib.Int32Array(heap);
        function hash(k, x) {
            // k in bytes
            k = k | 0;
            x = x | 0;
            var i = 0, j = 0, y0 = 0, z0 = 0, y1 = 0, z1 = 0, y2 = 0, z2 = 0, y3 = 0, z3 = 0, y4 = 0, z4 = 0, t0 = 0, t1 = 0;
            y0 = H[x + 320 >> 2] | 0;
            y1 = H[x + 324 >> 2] | 0;
            y2 = H[x + 328 >> 2] | 0;
            y3 = H[x + 332 >> 2] | 0;
            y4 = H[x + 336 >> 2] | 0;
            for (i = 0; (i | 0) < (k | 0); i = i + 64 | 0) {
                z0 = y0;
                z1 = y1;
                z2 = y2;
                z3 = y3;
                z4 = y4;
                for (j = 0; (j | 0) < 64; j = j + 4 | 0) {
                    t1 = H[i + j >> 2] | 0;
                    t0 = ((y0 << 5 | y0 >>> 27) + (y1 & y2 | ~y1 & y3) | 0) + ((t1 + y4 | 0) + 1518500249 | 0) | 0;
                    y4 = y3;
                    y3 = y2;
                    y2 = y1 << 30 | y1 >>> 2;
                    y1 = y0;
                    y0 = t0;
                    H[k + j >> 2] = t1;
                }
                for (j = k + 64 | 0; (j | 0) < (k + 80 | 0); j = j + 4 | 0) {
                    t1 = (H[j - 12 >> 2] ^ H[j - 32 >> 2] ^ H[j - 56 >> 2] ^ H[j - 64 >> 2]) << 1 | (H[j - 12 >> 2] ^ H[j - 32 >> 2] ^ H[j - 56 >> 2] ^ H[j - 64 >> 2]) >>> 31;
                    t0 = ((y0 << 5 | y0 >>> 27) + (y1 & y2 | ~y1 & y3) | 0) + ((t1 + y4 | 0) + 1518500249 | 0) | 0;
                    y4 = y3;
                    y3 = y2;
                    y2 = y1 << 30 | y1 >>> 2;
                    y1 = y0;
                    y0 = t0;
                    H[j >> 2] = t1;
                }
                for (j = k + 80 | 0; (j | 0) < (k + 160 | 0); j = j + 4 | 0) {
                    t1 = (H[j - 12 >> 2] ^ H[j - 32 >> 2] ^ H[j - 56 >> 2] ^ H[j - 64 >> 2]) << 1 | (H[j - 12 >> 2] ^ H[j - 32 >> 2] ^ H[j - 56 >> 2] ^ H[j - 64 >> 2]) >>> 31;
                    t0 = ((y0 << 5 | y0 >>> 27) + (y1 ^ y2 ^ y3) | 0) + ((t1 + y4 | 0) + 1859775393 | 0) | 0;
                    y4 = y3;
                    y3 = y2;
                    y2 = y1 << 30 | y1 >>> 2;
                    y1 = y0;
                    y0 = t0;
                    H[j >> 2] = t1;
                }
                for (j = k + 160 | 0; (j | 0) < (k + 240 | 0); j = j + 4 | 0) {
                    t1 = (H[j - 12 >> 2] ^ H[j - 32 >> 2] ^ H[j - 56 >> 2] ^ H[j - 64 >> 2]) << 1 | (H[j - 12 >> 2] ^ H[j - 32 >> 2] ^ H[j - 56 >> 2] ^ H[j - 64 >> 2]) >>> 31;
                    t0 = ((y0 << 5 | y0 >>> 27) + (y1 & y2 | y1 & y3 | y2 & y3) | 0) + ((t1 + y4 | 0) - 1894007588 | 0) | 0;
                    y4 = y3;
                    y3 = y2;
                    y2 = y1 << 30 | y1 >>> 2;
                    y1 = y0;
                    y0 = t0;
                    H[j >> 2] = t1;
                }
                for (j = k + 240 | 0; (j | 0) < (k + 320 | 0); j = j + 4 | 0) {
                    t1 = (H[j - 12 >> 2] ^ H[j - 32 >> 2] ^ H[j - 56 >> 2] ^ H[j - 64 >> 2]) << 1 | (H[j - 12 >> 2] ^ H[j - 32 >> 2] ^ H[j - 56 >> 2] ^ H[j - 64 >> 2]) >>> 31;
                    t0 = ((y0 << 5 | y0 >>> 27) + (y1 ^ y2 ^ y3) | 0) + ((t1 + y4 | 0) - 899497514 | 0) | 0;
                    y4 = y3;
                    y3 = y2;
                    y2 = y1 << 30 | y1 >>> 2;
                    y1 = y0;
                    y0 = t0;
                    H[j >> 2] = t1;
                }
                y0 = y0 + z0 | 0;
                y1 = y1 + z1 | 0;
                y2 = y2 + z2 | 0;
                y3 = y3 + z3 | 0;
                y4 = y4 + z4 | 0;
            }
            H[x + 320 >> 2] = y0;
            H[x + 324 >> 2] = y1;
            H[x + 328 >> 2] = y2;
            H[x + 332 >> 2] = y3;
            H[x + 336 >> 2] = y4;
        }
        return { hash: hash };
    };
    exports = Rusha;
    if (// If we'e running in Node.JS, export a module.
        typeof module !== 'undefined') {
        module.exports = Rusha;
    } else {// If we're running in Adblock Plus, export a module.
        exports = Rusha;
    }
    if (// If we're running in a webworker, accept
        // messages containing a jobid and a buffer
        // or blob object, and return the hash result.
        typeof FileReaderSync !== 'undefined') {
        var reader = new FileReaderSync(), hasher = new Rusha(4 * 1024 * 1024);
        self.onmessage = function onMessage(event) {
            var hash, data = event.data.data;
            try {
                hash = hasher.digest(data);
                self.postMessage({
                    id: event.data.id,
                    hash: hash
                });
            } catch (e) {
                self.postMessage({
                    id: event.data.id,
                    error: e.name
                });
            }
        };
    }
}());

return module.exports;
};

require.modules["subscriptionClasses"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview Definition of Subscription class and its subclasses.
 */

const {ActiveFilter, BlockingFilter,
       WhitelistFilter, ElemHideBase} = require("filterClasses");
const {FilterNotifier} = require("filterNotifier");
const {desc, extend} = require("coreUtils");

/**
 * Abstract base class for filter subscriptions
 *
 * @param {string} url    download location of the subscription
 * @param {string} [title]  title of the filter subscription
 * @constructor
 */
function Subscription(url, title)
{
  this.url = url;
  this.filters = [];
  if (title)
    this._title = title;
  Subscription.knownSubscriptions[url] = this;
}
exports.Subscription = Subscription;

Subscription.prototype =
{
  /**
   * Download location of the subscription
   * @type {string}
   */
  url: null,

  /**
   * Filters contained in the filter subscription
   * @type {Filter[]}
   */
  filters: null,

  _title: null,
  _fixedTitle: false,
  _disabled: false,

  /**
   * Title of the filter subscription
   * @type {string}
   */
  get title()
  {
    return this._title;
  },
  set title(value)
  {
    if (value != this._title)
    {
      let oldValue = this._title;
      this._title = value;
      FilterNotifier.triggerListeners("subscription.title",
                                      this, value, oldValue);
    }
    return this._title;
  },

  /**
   * Determines whether the title should be editable
   * @type {boolean}
   */
  get fixedTitle()
  {
    return this._fixedTitle;
  },
  set fixedTitle(value)
  {
    if (value != this._fixedTitle)
    {
      let oldValue = this._fixedTitle;
      this._fixedTitle = value;
      FilterNotifier.triggerListeners("subscription.fixedTitle",
                                      this, value, oldValue);
    }
    return this._fixedTitle;
  },

  /**
   * Defines whether the filters in the subscription should be disabled
   * @type {boolean}
   */
  get disabled()
  {
    return this._disabled;
  },
  set disabled(value)
  {
    if (value != this._disabled)
    {
      let oldValue = this._disabled;
      this._disabled = value;
      FilterNotifier.triggerListeners("subscription.disabled",
                                      this, value, oldValue);
    }
    return this._disabled;
  },

  /**
   * Serializes the subscription to an array of strings for writing
   * out on the disk.
   * @param {string[]} buffer  buffer to push the serialization results into
   */
  serialize(buffer)
  {
    buffer.push("[Subscription]");
    buffer.push("url=" + this.url);
    if (this._title)
      buffer.push("title=" + this._title);
    if (this._fixedTitle)
      buffer.push("fixedTitle=true");
    if (this._disabled)
      buffer.push("disabled=true");
  },

  serializeFilters(buffer)
  {
    for (let filter of this.filters)
      buffer.push(filter.text.replace(/\[/g, "\\["));
  },

  toString()
  {
    let buffer = [];
    this.serialize(buffer);
    return buffer.join("\n");
  }
};

/**
 * Cache for known filter subscriptions, maps URL to subscription objects.
 * @type {Object}
 */
Subscription.knownSubscriptions = Object.create(null);

/**
 * Returns a subscription from its URL, creates a new one if necessary.
 * @param {string} url
 *   URL of the subscription
 * @return {Subscription}
 *   subscription or null if the subscription couldn't be created
 */
Subscription.fromURL = function(url)
{
  if (url in Subscription.knownSubscriptions)
    return Subscription.knownSubscriptions[url];

  if (url[0] != "~")
    return new DownloadableSubscription(url, null);
  return new SpecialSubscription(url);
};

/**
 * Deserializes a subscription
 *
 * @param {Object}  obj
 *   map of serialized properties and their values
 * @return {Subscription}
 *   subscription or null if the subscription couldn't be created
 */
Subscription.fromObject = function(obj)
{
  let result;
  if (obj.url[0] != "~")
  {
    // URL is valid - this is a downloadable subscription
    result = new DownloadableSubscription(obj.url, obj.title);
    if ("downloadStatus" in obj)
      result._downloadStatus = obj.downloadStatus;
    if ("lastSuccess" in obj)
      result.lastSuccess = parseInt(obj.lastSuccess, 10) || 0;
    if ("lastCheck" in obj)
      result._lastCheck = parseInt(obj.lastCheck, 10) || 0;
    if ("expires" in obj)
      result.expires = parseInt(obj.expires, 10) || 0;
    if ("softExpiration" in obj)
      result.softExpiration = parseInt(obj.softExpiration, 10) || 0;
    if ("errors" in obj)
      result._errors = parseInt(obj.errors, 10) || 0;
    if ("version" in obj)
      result.version = parseInt(obj.version, 10) || 0;
    if ("requiredVersion" in obj)
      result.requiredVersion = obj.requiredVersion;
    if ("homepage" in obj)
      result._homepage = obj.homepage;
    if ("lastDownload" in obj)
      result._lastDownload = parseInt(obj.lastDownload, 10) || 0;
    if ("downloadCount" in obj)
      result.downloadCount = parseInt(obj.downloadCount, 10) || 0;
  }
  else
  {
    result = new SpecialSubscription(obj.url, obj.title);
    if ("defaults" in obj)
      result.defaults = obj.defaults.split(" ");
  }
  if ("fixedTitle" in obj)
    result._fixedTitle = (obj.fixedTitle == "true");
  if ("disabled" in obj)
    result._disabled = (obj.disabled == "true");

  return result;
};

/**
 * Class for special filter subscriptions (user's filters)
 * @param {string} url see Subscription()
 * @param {string} [title]  see Subscription()
 * @constructor
 * @augments Subscription
 */
function SpecialSubscription(url, title)
{
  Subscription.call(this, url, title);
}
exports.SpecialSubscription = SpecialSubscription;

SpecialSubscription.prototype = extend(Subscription, {
  /**
   * Filter types that should be added to this subscription by default
   * (entries should correspond to keys in SpecialSubscription.defaultsMap).
   * @type {string[]}
   */
  defaults: null,

  /**
   * Tests whether a filter should be added to this group by default
   * @param {Filter} filter filter to be tested
   * @return {boolean}
   */
  isDefaultFor(filter)
  {
    if (this.defaults && this.defaults.length)
    {
      for (let type of this.defaults)
      {
        if (filter instanceof SpecialSubscription.defaultsMap[type])
          return true;
        if (!(filter instanceof ActiveFilter) && type == "blacklist")
          return true;
      }
    }

    return false;
  },

  /**
   * See Subscription.serialize()
   * @inheritdoc
   */
  serialize(buffer)
  {
    Subscription.prototype.serialize.call(this, buffer);
    if (this.defaults && this.defaults.length)
    {
      buffer.push("defaults=" +
        this.defaults.filter(
          type => type in SpecialSubscription.defaultsMap
        ).join(" ")
      );
    }
    if (this._lastDownload)
      buffer.push("lastDownload=" + this._lastDownload);
  }
});

SpecialSubscription.defaultsMap = Object.create(null, desc({
  whitelist: WhitelistFilter,
  blocking: BlockingFilter,
  elemhide: ElemHideBase
}));

/**
 * Creates a new user-defined filter group.
 * @param {string} [title]  title of the new filter group
 * @return {SpecialSubscription}
 */
SpecialSubscription.create = function(title)
{
  let url;
  do
  {
    url = "~user~" + Math.round(Math.random() * 1000000);
  } while (url in Subscription.knownSubscriptions);
  return new SpecialSubscription(url, title);
};

/**
 * Creates a new user-defined filter group and adds the given filter to it.
 * This group will act as the default group for this filter type.
 * @param {Filter} filter
 * @return {SpecialSubscription}
 */
SpecialSubscription.createForFilter = function(filter)
{
  let subscription = SpecialSubscription.create();
  subscription.filters.push(filter);
  for (let type in SpecialSubscription.defaultsMap)
  {
    if (filter instanceof SpecialSubscription.defaultsMap[type])
      subscription.defaults = [type];
  }
  if (!subscription.defaults)
    subscription.defaults = ["blocking"];
  return subscription;
};

/**
 * Abstract base class for regular filter subscriptions (both
 * internally and externally updated)
 * @param {string} url    see Subscription()
 * @param {string} [title]  see Subscription()
 * @constructor
 * @augments Subscription
 */
function RegularSubscription(url, title)
{
  Subscription.call(this, url, title || url);
}
exports.RegularSubscription = RegularSubscription;

RegularSubscription.prototype = extend(Subscription, {
  _homepage: null,
  _lastDownload: 0,

  /**
   * Filter subscription homepage if known
   * @type {string}
   */
  get homepage()
  {
    return this._homepage;
  },
  set homepage(value)
  {
    if (value != this._homepage)
    {
      let oldValue = this._homepage;
      this._homepage = value;
      FilterNotifier.triggerListeners("subscription.homepage",
                                      this, value, oldValue);
    }
    return this._homepage;
  },

  /**
   * Time of the last subscription download (in seconds since the
   * beginning of the epoch)
   * @type {number}
   */
  get lastDownload()
  {
    return this._lastDownload;
  },
  set lastDownload(value)
  {
    if (value != this._lastDownload)
    {
      let oldValue = this._lastDownload;
      this._lastDownload = value;
      FilterNotifier.triggerListeners("subscription.lastDownload",
                                      this, value, oldValue);
    }
    return this._lastDownload;
  },

  /**
   * See Subscription.serialize()
   * @inheritdoc
   */
  serialize(buffer)
  {
    Subscription.prototype.serialize.call(this, buffer);
    if (this._homepage)
      buffer.push("homepage=" + this._homepage);
    if (this._lastDownload)
      buffer.push("lastDownload=" + this._lastDownload);
  }
});

/**
 * Class for filter subscriptions updated externally (by other extension)
 * @param {string} url    see Subscription()
 * @param {string} [title]  see Subscription()
 * @constructor
 * @augments RegularSubscription
 */
function ExternalSubscription(url, title)
{
  RegularSubscription.call(this, url, title);
}
exports.ExternalSubscription = ExternalSubscription;

ExternalSubscription.prototype = extend(RegularSubscription, {
  /**
   * See Subscription.serialize()
   * @inheritdoc
   */
  serialize(buffer)
  {
    throw new Error(
      "Unexpected call, external subscriptions should not be serialized"
    );
  }
});

/**
 * Class for filter subscriptions updated externally (by other extension)
 * @param {string} url  see Subscription()
 * @param {string} [title]  see Subscription()
 * @constructor
 * @augments RegularSubscription
 */
function DownloadableSubscription(url, title)
{
  RegularSubscription.call(this, url, title);
}
exports.DownloadableSubscription = DownloadableSubscription;

DownloadableSubscription.prototype = extend(RegularSubscription, {
  _downloadStatus: null,
  _lastCheck: 0,
  _errors: 0,

  /**
   * Status of the last download (ID of a string)
   * @type {string}
   */
  get downloadStatus()
  {
    return this._downloadStatus;
  },
  set downloadStatus(value)
  {
    let oldValue = this._downloadStatus;
    this._downloadStatus = value;
    FilterNotifier.triggerListeners("subscription.downloadStatus",
                                    this, value, oldValue);
    return this._downloadStatus;
  },

  /**
   * Time of the last successful download (in seconds since the beginning of the
   * epoch).
   */
  lastSuccess: 0,

  /**
   * Time when the subscription was considered for an update last time
   * (in seconds since the beginning of the epoch). This will be used
   * to increase softExpiration if the user doesn't use Adblock Plus
   * for some time.
   * @type {number}
   */
  get lastCheck()
  {
    return this._lastCheck;
  },
  set lastCheck(value)
  {
    if (value != this._lastCheck)
    {
      let oldValue = this._lastCheck;
      this._lastCheck = value;
      FilterNotifier.triggerListeners("subscription.lastCheck",
                                      this, value, oldValue);
    }
    return this._lastCheck;
  },

  /**
   * Hard expiration time of the filter subscription (in seconds since
   * the beginning of the epoch)
   * @type {number}
   */
  expires: 0,

  /**
   * Soft expiration time of the filter subscription (in seconds since
   * the beginning of the epoch)
   * @type {number}
   */
  softExpiration: 0,

  /**
   * Number of download failures since last success
   * @type {number}
   */
  get errors()
  {
    return this._errors;
  },
  set errors(value)
  {
    if (value != this._errors)
    {
      let oldValue = this._errors;
      this._errors = value;
      FilterNotifier.triggerListeners("subscription.errors", this,
                                      value, oldValue);
    }
    return this._errors;
  },

  /**
   * Version of the subscription data retrieved on last successful download
   * @type {number}
   */
  version: 0,

  /**
   * Minimal Adblock Plus version required for this subscription
   * @type {string}
   */
  requiredVersion: null,

  /**
   * Number indicating how often the object was downloaded.
   * @type {number}
   */
  downloadCount: 0,

  /**
   * See Subscription.serialize()
   * @inheritdoc
   */
  serialize(buffer)
  {
    RegularSubscription.prototype.serialize.call(this, buffer);
    if (this.downloadStatus)
      buffer.push("downloadStatus=" + this.downloadStatus);
    if (this.lastSuccess)
      buffer.push("lastSuccess=" + this.lastSuccess);
    if (this.lastCheck)
      buffer.push("lastCheck=" + this.lastCheck);
    if (this.expires)
      buffer.push("expires=" + this.expires);
    if (this.softExpiration)
      buffer.push("softExpiration=" + this.softExpiration);
    if (this.errors)
      buffer.push("errors=" + this.errors);
    if (this.version)
      buffer.push("version=" + this.version);
    if (this.requiredVersion)
      buffer.push("requiredVersion=" + this.requiredVersion);
    if (this.downloadCount)
      buffer.push("downloadCount=" + this.downloadCount);
  }
});

return module.exports;
};

require.modules["synchronizer"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

/**
 * @fileOverview Manages synchronization of filter subscriptions.
 */

const {Downloader, Downloadable,
       MILLIS_IN_SECOND, MILLIS_IN_MINUTE,
       MILLIS_IN_HOUR, MILLIS_IN_DAY} = require("downloader");
const {Filter} = require("filterClasses");
const {FilterStorage} = require("filterStorage");
const {FilterNotifier} = require("filterNotifier");
const {Prefs} = require("prefs");
const {Subscription, DownloadableSubscription} = require("subscriptionClasses");
const {Utils} = require("utils");

const INITIAL_DELAY = 1 * MILLIS_IN_MINUTE;
const CHECK_INTERVAL = 1 * MILLIS_IN_HOUR;
const DEFAULT_EXPIRATION_INTERVAL = 5 * MILLIS_IN_DAY;

/**
 * The object providing actual downloading functionality.
 * @type {Downloader}
 */
let downloader = null;

/**
 * This object is responsible for downloading filter subscriptions whenever
 * necessary.
 * @class
 */
let Synchronizer = exports.Synchronizer =
{
  /**
   * Called on module startup.
   */
  init()
  {
    downloader = new Downloader(this._getDownloadables.bind(this),
                                INITIAL_DELAY, CHECK_INTERVAL);
    onShutdown.add(() =>
    {
      downloader.cancel();
    });

    downloader.onExpirationChange = this._onExpirationChange.bind(this);
    downloader.onDownloadStarted = this._onDownloadStarted.bind(this);
    downloader.onDownloadSuccess = this._onDownloadSuccess.bind(this);
    downloader.onDownloadError = this._onDownloadError.bind(this);
  },

  /**
   * Checks whether a subscription is currently being downloaded.
   * @param {string} url  URL of the subscription
   * @return {boolean}
   */
  isExecuting(url)
  {
    return downloader.isDownloading(url);
  },

  /**
   * Starts the download of a subscription.
   * @param {DownloadableSubscription} subscription
   *   Subscription to be downloaded
   * @param {boolean} manual
   *   true for a manually started download (should not trigger fallback
   *   requests)
   */
  execute(subscription, manual)
  {
    downloader.download(this._getDownloadable(subscription, manual));
  },

  /**
   * Yields Downloadable instances for all subscriptions that can be downloaded.
   */
  *_getDownloadables()
  {
    if (!Prefs.subscriptions_autoupdate)
      return;

    for (let subscription of FilterStorage.subscriptions)
    {
      if (subscription instanceof DownloadableSubscription)
        yield this._getDownloadable(subscription, false);
    }
  },

  /**
   * Creates a Downloadable instance for a subscription.
   * @param {Subscription} subscription
   * @param {boolean} manual
   * @return {Downloadable}
   */
  _getDownloadable(subscription, manual)
  {
    let result = new Downloadable(subscription.url);
    if (subscription.lastDownload != subscription.lastSuccess)
      result.lastError = subscription.lastDownload * MILLIS_IN_SECOND;
    result.lastCheck = subscription.lastCheck * MILLIS_IN_SECOND;
    result.lastVersion = subscription.version;
    result.softExpiration = subscription.softExpiration * MILLIS_IN_SECOND;
    result.hardExpiration = subscription.expires * MILLIS_IN_SECOND;
    result.manual = manual;
    result.downloadCount = subscription.downloadCount;
    return result;
  },

  _onExpirationChange(downloadable)
  {
    let subscription = Subscription.fromURL(downloadable.url);
    subscription.lastCheck = Math.round(
      downloadable.lastCheck / MILLIS_IN_SECOND
    );
    subscription.softExpiration = Math.round(
      downloadable.softExpiration / MILLIS_IN_SECOND
    );
    subscription.expires = Math.round(
      downloadable.hardExpiration / MILLIS_IN_SECOND
    );
  },

  _onDownloadStarted(downloadable)
  {
    let subscription = Subscription.fromURL(downloadable.url);
    FilterNotifier.triggerListeners("subscription.downloading", subscription);
  },

  _onDownloadSuccess(downloadable, responseText, errorCallback,
                     redirectCallback)
  {
    let lines = responseText.split(/[\r\n]+/);
    let headerMatch = /\[Adblock(?:\s*Plus\s*([\d.]+)?)?\]/i.exec(lines[0]);
    if (!headerMatch)
      return errorCallback("synchronize_invalid_data");
    let minVersion = headerMatch[1];

    // Don't remove parameter comments immediately but add them to a list first,
    // they need to be considered in the checksum calculation.
    let remove = [];
    let params = {
      redirect: null,
      homepage: null,
      title: null,
      version: null,
      expires: null
    };
    for (let i = 0; i < lines.length; i++)
    {
      let match = /^\s*!\s*(\w+)\s*:\s*(.*)/.exec(lines[i]);
      if (match)
      {
        let keyword = match[1].toLowerCase();
        let value = match[2];
        if (keyword in params)
        {
          params[keyword] = value;
          remove.push(i);
        }
        else if (keyword == "checksum")
        {
          lines.splice(i--, 1);
          let checksum = Utils.generateChecksum(lines);
          if (checksum && checksum != value.replace(/=+$/, ""))
            return errorCallback("synchronize_checksum_mismatch");
        }
      }
    }

    if (params.redirect)
      return redirectCallback(params.redirect);

    // Handle redirects
    let subscription = Subscription.fromURL(downloadable.redirectURL ||
                                            downloadable.url);
    if (downloadable.redirectURL &&
        downloadable.redirectURL != downloadable.url)
    {
      let oldSubscription = Subscription.fromURL(downloadable.url);
      subscription.title = oldSubscription.title;
      subscription.disabled = oldSubscription.disabled;
      subscription.lastCheck = oldSubscription.lastCheck;

      let listed = (oldSubscription.url in FilterStorage.knownSubscriptions);
      if (listed)
        FilterStorage.removeSubscription(oldSubscription);

      delete Subscription.knownSubscriptions[oldSubscription.url];

      if (listed)
        FilterStorage.addSubscription(subscription);
    }

    // The download actually succeeded
    subscription.lastSuccess = subscription.lastDownload = Math.round(
      Date.now() / MILLIS_IN_SECOND
    );
    subscription.downloadStatus = "synchronize_ok";
    subscription.downloadCount = downloadable.downloadCount;
    subscription.errors = 0;

    // Remove lines containing parameters
    for (let i = remove.length - 1; i >= 0; i--)
      lines.splice(remove[i], 1);

    // Process parameters
    if (params.homepage)
    {
      let url;
      try
      {
        url = new URL(params.homepage);
      }
      catch (e)
      {
        url = null;
      }

      if (url && (url.protocol == "http:" || url.protocol == "https:"))
        subscription.homepage = url.href;
    }

    if (params.title)
    {
      subscription.title = params.title;
      subscription.fixedTitle = true;
    }
    else
      subscription.fixedTitle = false;

    subscription.version = (params.version ? parseInt(params.version, 10) : 0);

    let expirationInterval = DEFAULT_EXPIRATION_INTERVAL;
    if (params.expires)
    {
      let match = /^(\d+)\s*(h)?/.exec(params.expires);
      if (match)
      {
        let interval = parseInt(match[1], 10);
        if (match[2])
          expirationInterval = interval * MILLIS_IN_HOUR;
        else
          expirationInterval = interval * MILLIS_IN_DAY;
      }
    }

    let [
      softExpiration,
      hardExpiration
    ] = downloader.processExpirationInterval(expirationInterval);
    subscription.softExpiration = Math.round(softExpiration / MILLIS_IN_SECOND);
    subscription.expires = Math.round(hardExpiration / MILLIS_IN_SECOND);

    if (minVersion)
      subscription.requiredVersion = minVersion;
    else
      delete subscription.requiredVersion;

    // Process filters
    lines.shift();
    let filters = [];
    for (let line of lines)
    {
      line = Filter.normalize(line);
      if (line)
        filters.push(Filter.fromText(line));
    }

    FilterStorage.updateSubscriptionFilters(subscription, filters);

    return undefined;
  },

  _onDownloadError(downloadable, downloadURL, error, channelStatus,
                   responseStatus, redirectCallback)
  {
    let subscription = Subscription.fromURL(downloadable.url);
    subscription.lastDownload = Math.round(Date.now() / MILLIS_IN_SECOND);
    subscription.downloadStatus = error;

    // Request fallback URL if necessary - for automatic updates only
    if (!downloadable.manual)
    {
      subscription.errors++;

      if (redirectCallback &&
          subscription.errors >= Prefs.subscriptions_fallbackerrors &&
          /^https?:\/\//i.test(subscription.url))
      {
        subscription.errors = 0;

        let fallbackURL = Prefs.subscriptions_fallbackurl;
        const {addonVersion} = require("info");
        fallbackURL = fallbackURL.replace(/%VERSION%/g,
                                          encodeURIComponent(addonVersion));
        fallbackURL = fallbackURL.replace(/%SUBSCRIPTION%/g,
                                          encodeURIComponent(subscription.url));
        fallbackURL = fallbackURL.replace(/%URL%/g,
                                          encodeURIComponent(downloadURL));
        fallbackURL = fallbackURL.replace(/%ERROR%/g,
                                          encodeURIComponent(error));
        fallbackURL = fallbackURL.replace(/%CHANNELSTATUS%/g,
                                          encodeURIComponent(channelStatus));
        fallbackURL = fallbackURL.replace(/%RESPONSESTATUS%/g,
                                          encodeURIComponent(responseStatus));

        let request = new XMLHttpRequest();
        request.mozBackgroundRequest = true;
        request.open("GET", fallbackURL);
        request.overrideMimeType("text/plain");
        request.channel.loadFlags = request.channel.loadFlags |
                                    request.channel.INHIBIT_CACHING |
                                    request.channel.VALIDATE_ALWAYS;
        request.addEventListener("load", ev =>
        {
          if (onShutdown.done)
            return;

          if (!(subscription.url in FilterStorage.knownSubscriptions))
            return;

          let match = /^(\d+)(?:\s+(\S+))?$/.exec(request.responseText);
          if (match && match[1] == "301" &&    // Moved permanently
              match[2] && /^https?:\/\//i.test(match[2]))
          {
            redirectCallback(match[2]);
          }
          else if (match && match[1] == "410") // Gone
          {
            let data = "[Adblock]\n" +
              subscription.filters.map(f => f.text).join("\n");
            redirectCallback("data:text/plain," + encodeURIComponent(data));
          }
        }, false);
        request.send(null);
      }
    }
  }
};
Synchronizer.init();

return module.exports;
};

require.modules["antiadblockInit"] = function(module, exports)
{
/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

"use strict";

const {Prefs} = require("prefs");
const {ActiveFilter} = require("filterClasses");
const {FilterStorage} = require("filterStorage");
const {FilterNotifier} = require("filterNotifier");
const {Subscription} = require("subscriptionClasses");
const {Notification} = require("notification");

let ext;
if (typeof window != "undefined" && window.ext)
  ({ext} = window);
else
  ext = require("ext_background");

exports.initAntiAdblockNotification = function initAntiAdblockNotification()
{
  let notification = {
    id: "antiadblock",
    type: "question",
    title: ext.i18n.getMessage("notification_antiadblock_title"),
    message: ext.i18n.getMessage("notification_antiadblock_message"),
    urlFilters: []
  };

  function notificationListener(approved)
  {
    let subscription = Subscription.fromURL(Prefs.subscriptions_antiadblockurl);
    if (subscription.url in FilterStorage.knownSubscriptions)
      subscription.disabled = !approved;
  }

  function addAntiAdblockNotification(subscription)
  {
    let urlFilters = [];
    for (let filter of subscription.filters)
    {
      if (filter instanceof ActiveFilter)
      {
        for (let domain in filter.domains)
        {
          let urlFilter = "||" + domain + "^$document";
          if (domain && filter.domains[domain] &&
              urlFilters.indexOf(urlFilter) == -1)
            urlFilters.push(urlFilter);
        }
      }
    }
    notification.urlFilters = urlFilters;
    Notification.addNotification(notification);
    Notification.addQuestionListener(notification.id, notificationListener);
  }

  function removeAntiAdblockNotification()
  {
    Notification.removeNotification(notification);
    Notification.removeQuestionListener(notification.id, notificationListener);
  }

  let antiAdblockSubscription = Subscription.fromURL(
    Prefs.subscriptions_antiadblockurl
  );
  if (antiAdblockSubscription.lastDownload && antiAdblockSubscription.disabled)
    addAntiAdblockNotification(antiAdblockSubscription);

  function onSubscriptionChange(subscription)
  {
    let url = Prefs.subscriptions_antiadblockurl;
    if (url != subscription.url)
      return;

    if (url in FilterStorage.knownSubscriptions && subscription.disabled)
      addAntiAdblockNotification(subscription);
    else
      removeAntiAdblockNotification();
  }

  FilterNotifier.on("subscription.updated", onSubscriptionChange);
  FilterNotifier.on("subscription.removed", onSubscriptionChange);
  FilterNotifier.on("subscription.disabled", onSubscriptionChange);
};

return module.exports;
};

require("filterListener");
require("synchronizer");
require("requestBlocker");
require("popupBlocker");
require("subscriptionInit");
require("filterComposer");
require("stats");
require("uninstall");
require("csp");
require("cssInjection");

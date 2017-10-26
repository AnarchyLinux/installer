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

let {splitSelector} = require("common");
let {ElemHideEmulation} = require("content_elemHideEmulation");

// This variable is also used by our other content scripts.
let elemhide;

const typeMap = new Map([
  ["img", "IMAGE"],
  ["input", "IMAGE"],
  ["picture", "IMAGE"],
  ["audio", "MEDIA"],
  ["video", "MEDIA"],
  ["frame", "SUBDOCUMENT"],
  ["iframe", "SUBDOCUMENT"],
  ["object", "OBJECT"],
  ["embed", "OBJECT"]
]);

function getURLsFromObjectElement(element)
{
  let url = element.getAttribute("data");
  if (url)
    return [url];

  for (let child of element.children)
  {
    if (child.localName != "param")
      continue;

    let name = child.getAttribute("name");
    if (name != "movie" &&  // Adobe Flash
        name != "source" && // Silverlight
        name != "src" &&    // Real Media + Quicktime
        name != "FileName") // Windows Media
      continue;

    let value = child.getAttribute("value");
    if (!value)
      continue;

    return [value];
  }

  return [];
}

function getURLsFromAttributes(element)
{
  let urls = [];

  if (element.src)
    urls.push(element.src);

  if (element.srcset)
  {
    for (let candidate of element.srcset.split(","))
    {
      let url = candidate.trim().replace(/\s+\S+$/, "");
      if (url)
        urls.push(url);
    }
  }

  return urls;
}

function getURLsFromMediaElement(element)
{
  let urls = getURLsFromAttributes(element);

  for (let child of element.children)
  {
    if (child.localName == "source" || child.localName == "track")
      urls.push(...getURLsFromAttributes(child));
  }

  if (element.poster)
    urls.push(element.poster);

  return urls;
}

function getURLsFromElement(element)
{
  let urls;
  switch (element.localName)
  {
    case "object":
      urls = getURLsFromObjectElement(element);
      break;

    case "video":
    case "audio":
    case "picture":
      urls = getURLsFromMediaElement(element);
      break;

    default:
      urls = getURLsFromAttributes(element);
      break;
  }

  for (let i = 0; i < urls.length; i++)
  {
    if (/^(?!https?:)[\w-]+:/i.test(urls[i]))
      urls.splice(i--, 1);
  }

  return urls;
}

function hideElement(element)
{
  function doHide()
  {
    let propertyName = "display";
    let propertyValue = "none";
    if (element.localName == "frame")
    {
      propertyName = "visibility";
      propertyValue = "hidden";
    }

    if (element.style.getPropertyValue(propertyName) != propertyValue ||
        element.style.getPropertyPriority(propertyName) != "important")
      element.style.setProperty(propertyName, propertyValue, "important");
  }

  doHide();

  new MutationObserver(doHide).observe(
    element, {
      attributes: true,
      attributeFilter: ["style"]
    }
  );
}

function checkCollapse(element)
{
  let mediatype = typeMap.get(element.localName);
  if (!mediatype)
    return;

  let urls = getURLsFromElement(element);
  if (urls.length == 0)
    return;

  ext.backgroundPage.sendMessage(
    {
      type: "filters.collapse",
      urls,
      mediatype,
      baseURL: document.location.href
    },

    collapse =>
    {
      if (collapse)
      {
        hideElement(element);
      }
    }
  );
}

function checkSitekey()
{
  let attr = document.documentElement.getAttribute("data-adblockkey");
  if (attr)
    ext.backgroundPage.sendMessage({type: "filters.addKey", token: attr});
}

function ElementHidingTracer()
{
  this.selectors = [];
  this.changedNodes = [];
  this.timeout = null;
  this.observer = new MutationObserver(this.observe.bind(this));
  this.trace = this.trace.bind(this);

  if (document.readyState == "loading")
    document.addEventListener("DOMContentLoaded", this.trace);
  else
    this.trace();
}
ElementHidingTracer.prototype = {
  addSelectors(selectors, filters)
  {
    let pairs = selectors.map((sel, i) => [sel, filters && filters[i]]);

    if (document.readyState != "loading")
      this.checkNodes([document], pairs);

    this.selectors.push(...pairs);
  },

  checkNodes(nodes, pairs)
  {
    let selectors = [];
    let filters = [];

    for (let [selector, filter] of pairs)
    {
      nodes: for (let node of nodes)
      {
        for (let element of node.querySelectorAll(selector))
        {
          // Only consider selectors that actually have an effect on the
          // computed styles, and aren't overridden by rules with higher
          // priority, or haven't been circumvented in a different way.
          if (getComputedStyle(element).display == "none")
          {
            // For regular element hiding, we don't know the exact filter,
            // but the background page can find it with the given selector.
            // In case of element hiding emulation, the generated selector
            // we got here is different from the selector part of the filter,
            // but in this case we can send the whole filter text instead.
            if (filter)
              filters.push(filter);
            else
              selectors.push(selector);

            break nodes;
          }
        }
      }
    }

    if (selectors.length > 0 || filters.length > 0)
    {
      ext.backgroundPage.sendMessage({
        type: "devtools.traceElemHide",
        selectors, filters
      });
    }
  },

  onTimeout()
  {
    this.checkNodes(this.changedNodes, this.selectors);
    this.changedNodes = [];
    this.timeout = null;
  },

  observe(mutations)
  {
    // Forget previously changed nodes that are no longer in the DOM.
    for (let i = 0; i < this.changedNodes.length; i++)
    {
      if (!document.contains(this.changedNodes[i]))
        this.changedNodes.splice(i--, 1);
    }

    for (let mutation of mutations)
    {
      let node = mutation.target;

      // Ignore mutations of nodes that aren't in the DOM anymore.
      if (!document.contains(node))
        continue;

      // Since querySelectorAll() doesn't consider the root itself
      // and since CSS selectors can also match siblings, we have
      // to consider the parent node for attribute mutations.
      if (mutation.type == "attributes")
        node = node.parentNode;

      let addNode = true;
      for (let i = 0; i < this.changedNodes.length; i++)
      {
        let previouslyChangedNode = this.changedNodes[i];

        // If we are already going to check an ancestor of this node,
        // we can ignore this node, since it will be considered anyway
        // when checking one of its ancestors.
        if (previouslyChangedNode.contains(node))
        {
          addNode = false;
          break;
        }

        // If this node is an ancestor of a node that previously changed,
        // we can ignore that node, since it will be considered anyway
        // when checking one of its ancestors.
        if (node.contains(previouslyChangedNode))
          this.changedNodes.splice(i--, 1);
      }

      if (addNode)
        this.changedNodes.push(node);
    }

    // Check only nodes whose descendants have changed, and not more often
    // than once a second. Otherwise large pages with a lot of DOM mutations
    // (like YouTube) freeze when the devtools panel is active.
    if (this.timeout == null)
      this.timeout = setTimeout(this.onTimeout.bind(this), 1000);
  },

  trace()
  {
    this.checkNodes([document], this.selectors);

    this.observer.observe(
      document,
      {
        childList: true,
        attributes: true,
        subtree: true
      }
    );
  },

  disconnect()
  {
    document.removeEventListener("DOMContentLoaded", this.trace);
    this.observer.disconnect();
    clearTimeout(this.timeout);
  }
};

function ElemHide()
{
  this.shadow = this.createShadowTree();
  this.style = null;
  this.tracer = null;
  this.inject = true;

  this.elemHideEmulation = new ElemHideEmulation(
    window,
    callback =>
    {
      ext.backgroundPage.sendMessage({
        type: "filters.get",
        what: "elemhideemulation"
      }, callback);
    },
    this.addSelectors.bind(this),
    this.hideElements.bind(this)
  );
}
ElemHide.prototype = {
  selectorGroupSize: 200,

  createShadowTree()
  {
    // Use Shadow DOM if available as to not mess with with web pages that
    // rely on the order of their own <style> tags (#309). However, creating
    // a shadow root breaks running CSS transitions. So we have to create
    // the shadow root before transistions might start (#452).
    if (!("createShadowRoot" in document.documentElement))
      return null;

    // Using shadow DOM causes issues on some Google websites,
    // including Google Docs, Gmail and Blogger (#1770, #2602, #2687).
    if (/\.(?:google|blogger)\.com$/.test(document.domain))
      return null;

    // Finally since some users have both AdBlock and Adblock Plus installed we
    // have to consider how the two extensions interact. For example we want to
    // avoid creating the shadowRoot twice.
    let shadow = document.documentElement.shadowRoot ||
                 document.documentElement.createShadowRoot();
    shadow.appendChild(document.createElement("shadow"));

    return shadow;
  },

  injectSelectors(selectors, filters)
  {
    if (!this.style)
    {
      // Create <style> element lazily, only if we add styles. Add it to
      // the shadow DOM if possible. Otherwise fallback to the <head> or
      // <html> element. If we have injected a style element before that
      // has been removed (the sheet property is null), create a new one.
      this.style = document.createElement("style");
      (this.shadow || document.head ||
                      document.documentElement).appendChild(this.style);

      // It can happen that the frame already navigated to a different
      // document while we were waiting for the background page to respond.
      // In that case the sheet property will stay null, after addind the
      // <style> element to the shadow DOM.
      if (!this.style.sheet)
        return;
    }

    // If using shadow DOM, we have to add the ::content pseudo-element
    // before each selector, in order to match elements within the
    // insertion point.
    let preparedSelectors = [];
    if (this.shadow)
    {
      for (let selector of selectors)
      {
        let subSelectors = splitSelector(selector);
        for (let subSelector of subSelectors)
          preparedSelectors.push("::content " + subSelector);
      }
    }
    else
    {
      preparedSelectors = selectors;
    }

    // Safari only allows 8192 primitive selectors to be injected at once[1], we
    // therefore chunk the inserted selectors into groups of 200 to be safe.
    // (Chrome also has a limit, larger... but we're not certain exactly what it
    //  is! Edge apparently has no such limit.)
    // [1] - https://github.com/WebKit/webkit/blob/1cb2227f6b2a1035f7bdc46e5ab69debb75fc1de/Source/WebCore/css/RuleSet.h#L68
    for (let i = 0; i < preparedSelectors.length; i += this.selectorGroupSize)
    {
      let selector = preparedSelectors.slice(
        i, i + this.selectorGroupSize
      ).join(", ");
      this.style.sheet.insertRule(selector + "{display: none !important;}",
                                  this.style.sheet.cssRules.length);
    }
  },

  addSelectors(selectors, filters)
  {
    if (!selectors || selectors.length == 0)
      return;

    if (this.inject)
    {
      // Insert the style rules inline if we have been instructed by the
      // background page to do so. This is usually the case, except on platforms
      // that do support user stylesheets via the chrome.tabs.insertCSS API
      // (Firefox 53 onwards for now and possibly Chrome in the near future).
      // Once all supported platforms have implemented this API, we can remove
      // the code below. See issue #5090.
      // Related Chrome and Firefox issues:
      // https://bugs.chromium.org/p/chromium/issues/detail?id=632009
      // https://bugzilla.mozilla.org/show_bug.cgi?id=1310026
      this.injectSelectors(selectors, filters);
    }
    else
    {
      ext.backgroundPage.sendMessage({
        type: "elemhide.injectSelectors",
        selectors
      });
    }

    if (this.tracer)
      this.tracer.addSelectors(selectors, filters);
  },

  hideElements(elements, filters)
  {
    for (let element of elements)
      hideElement(element);

    if (this.tracer)
    {
      ext.backgroundPage.sendMessage({
        type: "devtools.traceElemHide",
        selectors: [],
        filters
      });
    }
  },

  apply()
  {
    ext.backgroundPage.sendMessage({type: "elemhide.getSelectors"}, response =>
    {
      if (this.tracer)
        this.tracer.disconnect();
      this.tracer = null;

      if (this.style && this.style.parentElement)
        this.style.parentElement.removeChild(this.style);
      this.style = null;

      if (response.trace)
        this.tracer = new ElementHidingTracer();

      this.inject = response.inject;

      if (this.inject)
        this.addSelectors(response.selectors);
      else if (this.tracer)
        this.tracer.addSelectors(response.selectors);

      this.elemHideEmulation.apply();
    });
  }
};

if (document instanceof HTMLDocument)
{
  checkSitekey();

  elemhide = new ElemHide();
  elemhide.apply();

  document.addEventListener("error", event =>
  {
    checkCollapse(event.target);
  }, true);

  document.addEventListener("load", event =>
  {
    let element = event.target;
    if (/^i?frame$/.test(element.localName))
      checkCollapse(element);
  }, true);
}

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

let randomEventName = "abp-request-" + Math.random().toString(36).substr(2);

// Proxy "should we block?" messages from checkRequest inside the injected
// code to the background page and back again.
document.addEventListener(randomEventName, event =>
{
  let {url, requestType} = event.detail;

  ext.backgroundPage.sendMessage({
    type: "request.blockedByWrapper",
    requestType,
    url
  }, block =>
  {
    document.dispatchEvent(new CustomEvent(
      randomEventName + "-" + requestType + "-" + url, {detail: block}
    ));
  });
});

function injected(eventName, injectedIntoContentWindow)
{
  let checkRequest;

  /*
   * Frame context wrapper
   *
   * For some edge-cases Chrome will not run content scripts inside of frames.
   * Website have started to abuse this fact to access unwrapped APIs via a
   * frame's contentWindow (#4586, 5207). Therefore until Chrome runs content
   * scripts consistently for all frames we must take care to (re)inject our
   * wrappers when the contentWindow is accessed.
   */
  let injectedToString = Function.prototype.toString.bind(injected);
  let injectedFrames = new WeakSet();
  let injectedFramesAdd = WeakSet.prototype.add.bind(injectedFrames);
  let injectedFramesHas = WeakSet.prototype.has.bind(injectedFrames);

  function injectIntoContentWindow(contentWindow)
  {
    if (contentWindow && !injectedFramesHas(contentWindow))
    {
      injectedFramesAdd(contentWindow);
      try
      {
        contentWindow[eventName] = checkRequest;
        contentWindow.eval(
          "(" + injectedToString() + ")('" + eventName + "', true);"
        );
        delete contentWindow[eventName];
      }
      catch (e) {}
    }
  }

  for (let element of [HTMLFrameElement, HTMLIFrameElement, HTMLObjectElement])
  {
    let contentDocumentDesc = Object.getOwnPropertyDescriptor(
      element.prototype, "contentDocument"
    );
    let contentWindowDesc = Object.getOwnPropertyDescriptor(
      element.prototype, "contentWindow"
    );

    // Apparently in HTMLObjectElement.prototype.contentWindow does not exist
    // in older versions of Chrome such as 42.
    if (!contentWindowDesc)
      continue;

    let getContentDocument = Function.prototype.call.bind(
      contentDocumentDesc.get
    );
    let getContentWindow = Function.prototype.call.bind(
      contentWindowDesc.get
    );

    contentWindowDesc.get = function()
    {
      let contentWindow = getContentWindow(this);
      injectIntoContentWindow(contentWindow);
      return contentWindow;
    };
    contentDocumentDesc.get = function()
    {
      injectIntoContentWindow(getContentWindow(this));
      return getContentDocument(this);
    };
    Object.defineProperty(element.prototype, "contentWindow",
                          contentWindowDesc);
    Object.defineProperty(element.prototype, "contentDocument",
                          contentDocumentDesc);
  }

  /*
   * Shadow root getter wrapper
   *
   * After creating our shadowRoot we must wrap the getter to prevent the
   * website from accessing it (#4191, #4298). This is required as a
   * workaround for the lack of user style support in Chrome.
   * See https://bugs.chromium.org/p/chromium/issues/detail?id=632009&desc=2
   */
  if ("shadowRoot" in Element.prototype)
  {
    let ourShadowRoot = document.documentElement.shadowRoot;
    if (ourShadowRoot)
    {
      let desc = Object.getOwnPropertyDescriptor(Element.prototype,
                                                 "shadowRoot");
      let shadowRoot = Function.prototype.call.bind(desc.get);

      Object.defineProperty(Element.prototype, "shadowRoot", {
        configurable: true, enumerable: true, get()
        {
          let thisShadow = shadowRoot(this);
          return thisShadow == ourShadowRoot ? null : thisShadow;
        }
      });
    }
  }

  /*
   * Shared request checking code, used by both the WebSocket and
   * RTCPeerConnection wrappers.
   */
  let RealCustomEvent = window.CustomEvent;

  // If we've been injected into a frame via contentWindow then we can simply
  // grab the copy of checkRequest left for us by the parent document. Otherwise
  // we need to set it up now, along with the event handling functions.
  if (injectedIntoContentWindow)
    checkRequest = window[eventName];
  else
  {
    let addEventListener = document.addEventListener.bind(document);
    let dispatchEvent = document.dispatchEvent.bind(document);
    let removeEventListener = document.removeEventListener.bind(document);
    checkRequest = (requestType, url, callback) =>
    {
      let incomingEventName = eventName + "-" + requestType + "-" + url;

      function listener(event)
      {
        callback(event.detail);
        removeEventListener(incomingEventName, listener);
      }
      addEventListener(incomingEventName, listener);

      dispatchEvent(new RealCustomEvent(eventName,
                                        {detail: {url, requestType}}));
    };
  }

  // Only to be called before the page's code, not hardened.
  function copyProperties(src, dest, properties)
  {
    for (let name of properties)
    {
      if (src.hasOwnProperty(name))
      {
        Object.defineProperty(dest, name,
                              Object.getOwnPropertyDescriptor(src, name));
      }
    }
  }

  /*
   * WebSocket wrapper
   *
   * Required before Chrome 58, since the webRequest API didn't allow us to
   * intercept WebSockets.
   * See https://bugs.chromium.org/p/chromium/issues/detail?id=129353
   */
  let RealWebSocket = WebSocket;
  let closeWebSocket = Function.prototype.call.bind(
    RealWebSocket.prototype.close
  );

  function WrappedWebSocket(url, ...args)
  {
    // Throw correct exceptions if the constructor is used improperly.
    if (!(this instanceof WrappedWebSocket)) return RealWebSocket();
    if (arguments.length < 1) return new RealWebSocket();

    let websocket = new RealWebSocket(url, ...args);

    checkRequest("websocket", websocket.url, blocked =>
    {
      if (blocked)
        closeWebSocket(websocket);
    });

    return websocket;
  }
  WrappedWebSocket.prototype = RealWebSocket.prototype;
  window.WebSocket = WrappedWebSocket.bind();
  copyProperties(RealWebSocket, WebSocket,
                 ["CONNECTING", "OPEN", "CLOSING", "CLOSED", "prototype"]);
  RealWebSocket.prototype.constructor = WebSocket;

  /*
   * RTCPeerConnection wrapper
   *
   * The webRequest API in Chrome does not yet allow the blocking of
   * WebRTC connections.
   * See https://bugs.chromium.org/p/chromium/issues/detail?id=707683
   */
  let RealRTCPeerConnection = window.RTCPeerConnection ||
                                window.webkitRTCPeerConnection;
  let closeRTCPeerConnection = Function.prototype.call.bind(
    RealRTCPeerConnection.prototype.close
  );
  let RealArray = Array;
  let RealString = String;
  let {create: createObject, defineProperty} = Object;

  function normalizeUrl(url)
  {
    if (typeof url != "undefined")
      return RealString(url);
  }

  function safeCopyArray(originalArray, transform)
  {
    if (originalArray == null || typeof originalArray != "object")
      return originalArray;

    let safeArray = RealArray(originalArray.length);
    for (let i = 0; i < safeArray.length; i++)
    {
      defineProperty(safeArray, i, {
        configurable: false, enumerable: false, writable: false,
        value: transform(originalArray[i])
      });
    }
    defineProperty(safeArray, "length", {
      configurable: false, enumerable: false, writable: false,
      value: safeArray.length
    });
    return safeArray;
  }

  // It would be much easier to use the .getConfiguration method to obtain
  // the normalized and safe configuration from the RTCPeerConnection
  // instance. Unfortunately its not implemented as of Chrome unstable 59.
  // See https://www.chromestatus.com/feature/5271355306016768
  function protectConfiguration(configuration)
  {
    if (configuration == null || typeof configuration != "object")
      return configuration;

    let iceServers = safeCopyArray(
      configuration.iceServers,
      iceServer =>
      {
        let {url, urls} = iceServer;

        // RTCPeerConnection doesn't iterate through pseudo Arrays of urls.
        if (typeof urls != "undefined" && !(urls instanceof RealArray))
          urls = [urls];

        return createObject(iceServer, {
          url: {
            configurable: false, enumerable: false, writable: false,
            value: normalizeUrl(url)
          },
          urls: {
            configurable: false, enumerable: false, writable: false,
            value: safeCopyArray(urls, normalizeUrl)
          }
        });
      }
    );

    return createObject(configuration, {
      iceServers: {
        configurable: false, enumerable: false, writable: false,
        value: iceServers
      }
    });
  }

  function checkUrl(peerconnection, url)
  {
    checkRequest("webrtc", url, blocked =>
    {
      if (blocked)
      {
        // Calling .close() throws if already closed.
        try
        {
          closeRTCPeerConnection(peerconnection);
        }
        catch (e) {}
      }
    });
  }

  function checkConfiguration(peerconnection, configuration)
  {
    if (configuration && configuration.iceServers)
    {
      for (let i = 0; i < configuration.iceServers.length; i++)
      {
        let iceServer = configuration.iceServers[i];
        if (iceServer)
        {
          if (iceServer.url)
            checkUrl(peerconnection, iceServer.url);

          if (iceServer.urls)
          {
            for (let j = 0; j < iceServer.urls.length; j++)
              checkUrl(peerconnection, iceServer.urls[j]);
          }
        }
      }
    }
  }

  // Chrome unstable (tested with 59) has already implemented
  // setConfiguration, so we need to wrap that if it exists too.
  // https://www.chromestatus.com/feature/5596193748942848
  if (RealRTCPeerConnection.prototype.setConfiguration)
  {
    let realSetConfiguration = Function.prototype.call.bind(
      RealRTCPeerConnection.prototype.setConfiguration
    );

    RealRTCPeerConnection.prototype.setConfiguration = function(configuration)
    {
      configuration = protectConfiguration(configuration);

      // Call the real method first, so that validates the configuration for
      // us. Also we might as well since checkRequest is asynchronous anyway.
      realSetConfiguration(this, configuration);
      checkConfiguration(this, configuration);
    };
  }

  function WrappedRTCPeerConnection(...args)
  {
    if (!(this instanceof WrappedRTCPeerConnection))
      return RealRTCPeerConnection();

    let configuration = protectConfiguration(args[0]);

    // Since the old webkitRTCPeerConnection constructor takes an optional
    // second argument we need to take care to pass that through. Necessary
    // for older versions of Chrome such as 49.
    let constraints = undefined;
    if (args.length > 1)
      constraints = args[1];

    let peerconnection = new RealRTCPeerConnection(configuration, constraints);
    checkConfiguration(peerconnection, configuration);
    return peerconnection;
  }

  WrappedRTCPeerConnection.prototype = RealRTCPeerConnection.prototype;

  let boundWrappedRTCPeerConnection = WrappedRTCPeerConnection.bind();
  copyProperties(RealRTCPeerConnection, boundWrappedRTCPeerConnection,
                 ["generateCertificate", "name", "prototype"]);
  RealRTCPeerConnection.prototype.constructor = boundWrappedRTCPeerConnection;

  if ("RTCPeerConnection" in window)
    window.RTCPeerConnection = boundWrappedRTCPeerConnection;
  if ("webkitRTCPeerConnection" in window)
    window.webkitRTCPeerConnection = boundWrappedRTCPeerConnection;
}

if (document instanceof HTMLDocument)
{
  let sandbox = window.frameElement &&
                window.frameElement.getAttribute("sandbox");

  if (typeof sandbox != "string" || /(^|\s)allow-scripts(\s|$)/i.test(sandbox))
  {
    let script = document.createElement("script");
    script.type = "application/javascript";
    script.async = false;
    script.textContent = "(" + injected + ")('" + randomEventName + "');";
    document.documentElement.appendChild(script);
    document.documentElement.removeChild(script);
  }
}


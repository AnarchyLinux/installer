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

/* globals require */

"use strict";

(function(global)
{
  let ext = global.ext || require("ext_background");

  const {port} = require("messaging");
  const {Prefs} = require("prefs");
  const {Utils} = require("utils");
  const {FilterStorage} = require("filterStorage");
  const {FilterNotifier} = require("filterNotifier");
  const {defaultMatcher} = require("matcher");
  const {ElemHideEmulation} = require("elemHideEmulation");
  const {Notification: NotificationStorage} = require("notification");

  const {Filter, BlockingFilter, RegExpFilter} = require("filterClasses");
  const {Synchronizer} = require("synchronizer");

  const info = require("info");
  const {
    Subscription,
    DownloadableSubscription,
    SpecialSubscription
  } = require("subscriptionClasses");

  // Some modules doesn't exist on Firefox. Moreover,
  // require() throws an exception on Firefox in that case.
  // However, try/catch causes the whole function to to be
  // deoptimized on V8. So we wrap it into another function.
  function tryRequire(module)
  {
    try
    {
      return require(module);
    }
    catch (e)
    {
      return null;
    }
  }

  function convertObject(keys, obj)
  {
    let result = {};
    for (let key of keys)
    {
      if (key in obj)
        result[key] = obj[key];
    }
    return result;
  }

  function convertSubscription(subscription)
  {
    let obj = convertObject(["disabled", "downloadStatus", "homepage",
                             "lastDownload", "title", "url"], subscription);
    if (subscription instanceof SpecialSubscription)
      obj.filters = subscription.filters.map(convertFilter);
    obj.isDownloading = Synchronizer.isExecuting(subscription.url);
    return obj;
  }

  let convertFilter = convertObject.bind(null, ["text"]);

  let changeListeners = new ext.PageMap();
  let listenedPreferences = Object.create(null);
  let listenedFilterChanges = Object.create(null);
  let messageTypes = new Map([
    ["app", "app.respond"],
    ["filter", "filters.respond"],
    ["pref", "prefs.respond"],
    ["subscription", "subscriptions.respond"]
  ]);

  function sendMessage(type, action, ...args)
  {
    let pages = changeListeners.keys();
    if (pages.length == 0)
      return;

    let convertedArgs = [];
    for (let arg of args)
    {
      if (arg instanceof Subscription)
        convertedArgs.push(convertSubscription(arg));
      else if (arg instanceof Filter)
        convertedArgs.push(convertFilter(arg));
      else
        convertedArgs.push(arg);
    }

    for (let page of pages)
    {
      let filters = changeListeners.get(page);
      let actions = filters[type];
      if (actions && actions.indexOf(action) != -1)
      {
        page.sendMessage({
          type: messageTypes.get(type),
          action,
          args: convertedArgs
        });
      }
    }
  }

  function addFilterListeners(type, actions)
  {
    for (let action of actions)
    {
      let name;
      if (type == "filter" && action == "loaded")
        name = "load";
      else
        name = type + "." + action;

      if (!(name in listenedFilterChanges))
      {
        listenedFilterChanges[name] = null;
        FilterNotifier.on(name, (...args) =>
        {
          sendMessage(type, action, ...args);
        });
      }
    }
  }

  function getListenerFilters(page)
  {
    let listenerFilters = changeListeners.get(page);
    if (!listenerFilters)
    {
      listenerFilters = Object.create(null);
      changeListeners.set(page, listenerFilters);
    }
    return listenerFilters;
  }

  port.on("app.get", (message, sender) =>
  {
    if (message.what == "issues")
    {
      let subscriptionInit = tryRequire("subscriptionInit");
      let result = subscriptionInit ? subscriptionInit.reinitialized : false;
      return {filterlistsReinitialized: result};
    }

    if (message.what == "doclink")
      return Utils.getDocLink(message.link);

    if (message.what == "localeInfo")
    {
      let bidiDir;
      if ("chromeRegistry" in Utils)
      {
        let isRtl = Utils.chromeRegistry.isLocaleRTL("adblockplus");
        bidiDir = isRtl ? "rtl" : "ltr";
      }
      else
        bidiDir = Utils.readingDirection;

      return {locale: Utils.appLocale, bidiDir};
    }

    if (message.what == "features")
    {
      return {
        devToolsPanel: info.platform == "chromium"
      };
    }

    return info[message.what];
  });

  port.on("app.listen", (message, sender) =>
  {
    getListenerFilters(sender.page).app = message.filter;
  });

  port.on("app.open", (message, sender) =>
  {
    if (message.what == "options")
    {
      ext.showOptions(() =>
      {
        if (!message.action)
          return;

        sendMessage("app", message.action, ...message.args);
      });
    }
  });

  port.on("filters.add", (message, sender) =>
  {
    let result = require("filterValidation").parseFilter(message.text);
    let errors = [];
    if (result.error)
      errors.push(result.error.toString());
    else if (result.filter)
      FilterStorage.addFilter(result.filter);

    return errors;
  });

  port.on("filters.blocked", (message, sender) =>
  {
    let filter = defaultMatcher.matchesAny(message.url,
      RegExpFilter.typeMap[message.requestType], message.docDomain,
      message.thirdParty);

    return filter instanceof BlockingFilter;
  });

  port.on("filters.get", (message, sender) =>
  {
    if (message.what == "elemhideemulation")
    {
      let filters = [];
      const {checkWhitelisted} = require("whitelisting");

      let isWhitelisted = checkWhitelisted(sender.page, sender.frame,
        RegExpFilter.typeMap.DOCUMENT | RegExpFilter.typeMap.ELEMHIDE);
      if (Prefs.enabled && !isWhitelisted)
      {
        let {hostname} = sender.frame.url;
        filters = ElemHideEmulation.getRulesForDomain(hostname);
        filters = filters.map((filter) =>
        {
          return {
            selector: filter.selector,
            text: filter.text
          };
        });
      }
      return filters;
    }

    let subscription = Subscription.fromURL(message.subscriptionUrl);
    if (!subscription)
      return [];

    return subscription.filters.map(convertFilter);
  });

  port.on("filters.importRaw", (message, sender) =>
  {
    let result = require("filterValidation").parseFilters(message.text);
    let errors = [];
    for (let error of result.errors)
    {
      if (error.type != "unexpected-filter-list-header")
        errors.push(error.toString());
    }

    if (errors.length > 0)
      return errors;

    let seenFilter = Object.create(null);
    for (let filter of result.filters)
    {
      FilterStorage.addFilter(filter);
      seenFilter[filter.text] = null;
    }

    if (!message.removeExisting)
      return errors;

    for (let subscription of FilterStorage.subscriptions)
    {
      if (!(subscription instanceof SpecialSubscription))
        continue;

      for (let j = subscription.filters.length - 1; j >= 0; j--)
      {
        let filter = subscription.filters[j];
        if (/^@@\|\|([^/:]+)\^\$document$/.test(filter.text))
          continue;

        if (!(filter.text in seenFilter))
          FilterStorage.removeFilter(filter);
      }
    }

    return errors;
  });

  port.on("filters.listen", (message, sender) =>
  {
    getListenerFilters(sender.page).filter = message.filter;
    addFilterListeners("filter", message.filter);
  });

  port.on("filters.remove", (message, sender) =>
  {
    let filter = Filter.fromText(message.text);
    let subscription = null;
    if (message.subscriptionUrl)
      subscription = Subscription.fromURL(message.subscriptionUrl);

    if (!subscription)
      FilterStorage.removeFilter(filter);
    else
      FilterStorage.removeFilter(filter, subscription, message.index);
  });

  port.on("prefs.get", (message, sender) =>
  {
    return Prefs[message.key];
  });

  port.on("prefs.listen", (message, sender) =>
  {
    getListenerFilters(sender.page).pref = message.filter;
    for (let preference of message.filter)
    {
      if (!(preference in listenedPreferences))
      {
        listenedPreferences[preference] = null;
        Prefs.on(preference, () =>
        {
          sendMessage("pref", preference, Prefs[preference]);
        });
      }
    }
  });

  port.on("prefs.toggle", (message, sender) =>
  {
    if (message.key == "notifications_ignoredcategories")
      NotificationStorage.toggleIgnoreCategory("*");
    else
      Prefs[message.key] = !Prefs[message.key];
  });

  port.on("subscriptions.add", (message, sender) =>
  {
    let subscription = Subscription.fromURL(message.url);
    if ("title" in message)
      subscription.title = message.title;
    if ("homepage" in message)
      subscription.homepage = message.homepage;

    if (message.confirm)
    {
      ext.showOptions(() =>
      {
        sendMessage("app", "addSubscription", subscription);
      });
    }
    else
    {
      subscription.disabled = false;
      FilterStorage.addSubscription(subscription);

      if (subscription instanceof DownloadableSubscription &&
          !subscription.lastDownload)
        Synchronizer.execute(subscription);
    }
  });

  port.on("subscriptions.get", (message, sender) =>
  {
    let subscriptions = FilterStorage.subscriptions.filter((s) =>
    {
      if (message.ignoreDisabled && s.disabled)
        return false;
      if (s instanceof DownloadableSubscription && message.downloadable)
        return true;
      if (s instanceof SpecialSubscription && message.special)
        return true;
      return false;
    });

    return subscriptions.map(convertSubscription);
  });

  port.on("subscriptions.listen", (message, sender) =>
  {
    getListenerFilters(sender.page).subscription = message.filter;
    addFilterListeners("subscription", message.filter);
  });

  port.on("subscriptions.remove", (message, sender) =>
  {
    let subscription = Subscription.fromURL(message.url);
    if (subscription.url in FilterStorage.knownSubscriptions)
      FilterStorage.removeSubscription(subscription);
  });

  port.on("subscriptions.toggle", (message, sender) =>
  {
    let subscription = Subscription.fromURL(message.url);
    if (subscription.url in FilterStorage.knownSubscriptions)
    {
      if (subscription.disabled || message.keepInstalled)
        subscription.disabled = !subscription.disabled;
      else
        FilterStorage.removeSubscription(subscription);
    }
    else
    {
      subscription.disabled = false;
      subscription.title = message.title;
      subscription.homepage = message.homepage;
      FilterStorage.addSubscription(subscription);
      if (!subscription.lastDownload)
        Synchronizer.execute(subscription);
    }
  });

  port.on("subscriptions.update", (message, sender) =>
  {
    let {subscriptions} = FilterStorage;
    if (message.url)
      subscriptions = [Subscription.fromURL(message.url)];

    for (let subscription of subscriptions)
    {
      if (subscription instanceof DownloadableSubscription)
        Synchronizer.execute(subscription, true);
    }
  });
})(this);

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

/* global $, i18n, i18nTimeDateStrings */

"use strict";

/**
 * Creates a wrapping function used to conveniently send a type of message.
 *
 * @param {Object} baseMessage The part of the message that's always sent
 * @param {...string} paramKeys Any message keys that have dynamic values. The
 *                              returned function will take the corresponding
 *                              values as arguments.
 * @return {function} The generated messaging function, optionally
 *                    taking any values as specified by the paramKeys
 *                    and finally an optional callback.  (Although the
 *                    value arguments are optional their index must be
 *                    maintained. E.g. if you omit the first value you
 *                    must omit the second too.)
 */
function wrapper(baseMessage, ...paramKeys)
{
  return function(...paramValues /* , callback */)
  {
    let message = Object.assign(Object.create(null), baseMessage);
    let callback;

    if (paramValues.length > 0)
    {
      let lastArg = paramValues[paramValues.length - 1];
      if (typeof lastArg == "function")
        callback = lastArg;

      for (let i = 0; i < paramValues.length - (callback ? 1 : 0); i++)
        message[paramKeys[i]] = paramValues[i];
    }

    ext.backgroundPage.sendMessage(message, callback);
  };
}

const getDocLink = wrapper({type: "app.get", what: "doclink"}, "link");
const getInfo = wrapper({type: "app.get"}, "what");
const getPref = wrapper({type: "prefs.get"}, "key");
const togglePref = wrapper({type: "prefs.toggle"}, "key");
const getSubscriptions = wrapper({type: "subscriptions.get"},
                                 "downloadable", "special");
const removeSubscription = wrapper({type: "subscriptions.remove"}, "url");
const addSubscription = wrapper({type: "subscriptions.add"},
                                "url", "title", "homepage");
const toggleSubscription = wrapper({type: "subscriptions.toggle"},
                                   "url", "keepInstalled");
const updateSubscription = wrapper({type: "subscriptions.update"}, "url");
const importRawFilters = wrapper({type: "filters.importRaw"},
                                 "text", "removeExisting");
const addFilter = wrapper({type: "filters.add"}, "text");
const removeFilter = wrapper({type: "filters.remove"}, "text");
const quoteCSS = wrapper({type: "composer.quoteCSS"}, "CSS");

const whitelistedDomainRegexp = /^@@\|\|([^/:]+)\^\$document$/;
const statusMessages = new Map([
  ["synchronize_invalid_url",
   "filters_subscription_lastDownload_invalidURL"],
  ["synchronize_connection_error",
   "filters_subscription_lastDownload_connectionError"],
  ["synchronize_invalid_data",
   "filters_subscription_lastDownload_invalidData"],
  ["synchronize_checksum_mismatch",
   "filters_subscription_lastDownload_checksumMismatch"]
]);

let delayedSubscriptionSelection = null;
let acceptableAdsUrl;

// Loads options from localStorage and sets UI elements accordingly
function loadOptions()
{
  // Set page title to i18n version of "Adblock Plus Options"
  document.title = i18n.getMessage("options");

  // Set links
  getPref("subscriptions_exceptionsurl", url =>
  {
    acceptableAdsUrl = url;
    $("#acceptableAdsLink").attr("href", acceptableAdsUrl);
  });
  getDocLink("acceptable_ads", url =>
  {
    $("#acceptableAdsDocs").attr("href", url);
  });
  getDocLink("filterdoc", url =>
  {
    setLinks("filter-must-follow-syntax", url);
  });
  getInfo("application", application =>
  {
    getInfo("platform", platform =>
    {
      if (platform == "chromium" && application != "opera")
        application = "chrome";

      getDocLink(application + "_support", url =>
      {
        setLinks("found-a-bug", url);
      });

      if (platform == "gecko")
        $("#firefox-warning").removeAttr("hidden");
    });
  });

  // Add event listeners
  $("#updateFilterLists").click(updateFilterLists);
  $("#startSubscriptionSelection").click(startSubscriptionSelection);
  $("#subscriptionSelector").change(updateSubscriptionSelection);
  $("#addSubscription").click(addSubscriptionClicked);
  $("#acceptableAds").click(toggleAcceptableAds);
  $("#whitelistForm").submit(addWhitelistDomain);
  $("#removeWhitelist").click(removeSelectedExcludedDomain);
  $("#customFilterForm").submit(addTypedFilter);
  $("#removeCustomFilter").click(removeSelectedFilters);
  $("#rawFiltersButton").click(toggleFiltersInRawFormat);
  $("#importRawFilters").click(importRawFiltersText);

  // Display jQuery UI elements
  $("#tabs").tabs();
  $("button").button();
  $(".refreshButton").button("option", "icons", {primary: "ui-icon-refresh"});
  $(".addButton").button("option", "icons", {primary: "ui-icon-plus"});
  $(".removeButton").button("option", "icons", {primary: "ui-icon-minus"});

  // Popuplate option checkboxes
  initCheckbox("shouldShowBlockElementMenu");
  initCheckbox("show_devtools_panel");
  initCheckbox("shouldShowNotifications", "notifications_ignoredcategories");

  getInfo("features", features =>
  {
    if (!features.devToolsPanel)
      document.getElementById("showDevtoolsPanelContainer").hidden = true;
  });
  getPref("notifications_showui", showNotificationsUI =>
  {
    if (!showNotificationsUI)
      document.getElementById("shouldShowNotificationsContainer").hidden = true;
  });

  // Register listeners in the background message responder
  ext.backgroundPage.sendMessage({
    type: "app.listen",
    filter: ["addSubscription", "focusSection"]
  });
  ext.backgroundPage.sendMessage({
    type: "filters.listen",
    filter: ["added", "loaded", "removed"]
  });
  ext.backgroundPage.sendMessage({
    type: "prefs.listen",
    filter: ["notifications_ignoredcategories", "notifications_showui",
             "show_devtools_panel", "shouldShowBlockElementMenu"]
  });
  ext.backgroundPage.sendMessage({
    type: "subscriptions.listen",
    filter: ["added", "disabled", "homepage", "lastDownload", "removed",
             "title", "downloadStatus", "downloading"]
  });

  // Load recommended subscriptions
  loadRecommendations();

  // Show user's filters
  reloadFilters();
}
$(loadOptions);

function convertSpecialSubscription(subscription)
{
  for (let filter of subscription.filters)
  {
    if (whitelistedDomainRegexp.test(filter.text))
      appendToListBox("excludedDomainsBox", RegExp.$1);
    else
      appendToListBox("userFiltersBox", filter.text);
  }
}

// Reloads the displayed subscriptions and filters
function reloadFilters()
{
  // Load user filter URLs
  let container = document.getElementById("filterLists");
  while (container.lastChild)
    container.removeChild(container.lastChild);

  getSubscriptions(true, false, subscriptions =>
  {
    for (let subscription of subscriptions)
    {
      if (subscription.url == acceptableAdsUrl)
        $("#acceptableAds").prop("checked", !subscription.disabled);
      else
        addSubscriptionEntry(subscription);
    }
  });

  // User-entered filters
  getSubscriptions(false, true, subscriptions =>
  {
    document.getElementById("userFiltersBox").innerHTML = "";
    document.getElementById("excludedDomainsBox").innerHTML = "";

    for (let subscription of subscriptions)
      convertSpecialSubscription(subscription);
  });
}

function initCheckbox(id, key)
{
  key = key || id;
  let checkbox = document.getElementById(id);

  getPref(key, value =>
  {
    onPrefMessage(key, value);
  });

  checkbox.addEventListener("click", () =>
  {
    togglePref(key);
  }, false);
}

function loadRecommendations()
{
  fetch("subscriptions.xml")
    .then(response =>
    {
      return response.text();
    })
    .then(text =>
    {
      let selectedIndex = 0;
      let selectedPrefix = null;
      let matchCount = 0;

      let list = document.getElementById("subscriptionSelector");
      let doc = new DOMParser().parseFromString(text, "application/xml");
      let elements = doc.documentElement.getElementsByTagName("subscription");

      for (let i = 0; i < elements.length; i++)
      {
        let element = elements[i];
        let option = new Option();
        option.text = element.getAttribute("title") + " (" +
                      element.getAttribute("specialization") + ")";
        option._data = {
          title: element.getAttribute("title"),
          url: element.getAttribute("url"),
          homepage: element.getAttribute("homepage")
        };

        let prefix = element.getAttribute("prefixes");
        if (prefix)
        {
          prefix = prefix.replace(/\W/g, "_");
          option.style.fontWeight = "bold";
          option.style.backgroundColor = "#E0FFE0";
          option.style.color = "#000000";
          if (!selectedPrefix || selectedPrefix.length < prefix.length)
          {
            selectedIndex = i;
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
              selectedIndex = i;
              selectedPrefix = prefix;
            }
          }
        }
        list.appendChild(option);
      }

      let option = new Option();
      let label = i18n.getMessage("filters_addSubscriptionOther_label");
      option.text = label + "\u2026";
      option._data = null;
      list.appendChild(option);

      list.selectedIndex = selectedIndex;

      if (delayedSubscriptionSelection)
        startSubscriptionSelection(...delayedSubscriptionSelection);
    });
}

function startSubscriptionSelection(title, url)
{
  let list = document.getElementById("subscriptionSelector");
  if (list.length == 0)
  {
    delayedSubscriptionSelection = [title, url];
    return;
  }

  $("#tabs").tabs("select", 0);
  $("#addSubscriptionContainer").show();
  $("#addSubscriptionButton").hide();
  $("#subscriptionSelector").focus();
  if (typeof url != "undefined")
  {
    list.selectedIndex = list.length - 1;
    document.getElementById("customSubscriptionTitle").value = title;
    document.getElementById("customSubscriptionLocation").value = url;
  }
  updateSubscriptionSelection();
  document.getElementById("addSubscriptionContainer").scrollIntoView(true);
}

function updateSubscriptionSelection()
{
  let list = document.getElementById("subscriptionSelector");
  let data = list.options[list.selectedIndex]._data;
  if (data)
    $("#customSubscriptionContainer").hide();
  else
  {
    $("#customSubscriptionContainer").show();
    $("#customSubscriptionTitle").focus();
  }
}

function addSubscriptionClicked()
{
  let list = document.getElementById("subscriptionSelector");
  let data = list.options[list.selectedIndex]._data;
  if (data)
    addSubscription(data.url, data.title, data.homepage);
  else
  {
    let url = document.getElementById("customSubscriptionLocation")
                      .value.trim();
    if (!/^https?:/i.test(url))
    {
      alert(i18n.getMessage("global_subscription_invalid_location"));
      $("#customSubscriptionLocation").focus();
      return;
    }

    let title = document.getElementById("customSubscriptionTitle").value.trim();
    if (!title)
      title = url;

    addSubscription(url, title, null);
  }

  $("#addSubscriptionContainer").hide();
  $("#customSubscriptionContainer").hide();
  $("#addSubscriptionButton").show();
}

function toggleAcceptableAds()
{
  toggleSubscription(acceptableAdsUrl, true);
}

function findSubscriptionElement(subscription)
{
  for (let child of document.getElementById("filterLists").childNodes)
  {
    if (child._subscription.url == subscription.url)
      return child;
  }
  return null;
}

function updateSubscriptionInfo(element, subscription)
{
  if (subscription)
    element._subscription = subscription;
  else
    subscription = element._subscription;

  let title = element.getElementsByClassName("subscriptionTitle")[0];
  title.textContent = subscription.title;
  title.setAttribute("title", subscription.url);
  if (subscription.homepage)
    title.href = subscription.homepage;
  else
    title.href = subscription.url;

  let enabled = element.getElementsByClassName("subscriptionEnabled")[0];
  enabled.checked = !subscription.disabled;

  let lastUpdate = element.getElementsByClassName("subscriptionUpdate")[0];
  lastUpdate.classList.remove("error");

  let {downloadStatus} = subscription;
  if (subscription.isDownloading)
  {
    lastUpdate.textContent = i18n.getMessage(
      "filters_subscription_lastDownload_inProgress"
    );
  }
  else if (downloadStatus && downloadStatus != "synchronize_ok")
  {
    if (statusMessages.has(downloadStatus))
    {
      lastUpdate.textContent = i18n.getMessage(
        statusMessages.get(downloadStatus)
      );
    }
    else
      lastUpdate.textContent = downloadStatus;
    lastUpdate.classList.add("error");
  }
  else if (subscription.lastDownload > 0)
  {
    let timeDate = i18nTimeDateStrings(subscription.lastDownload * 1000);
    let messageID = (timeDate[1] ? "last_updated_at" : "last_updated_at_today");
    lastUpdate.textContent = i18n.getMessage(messageID, timeDate);
  }
}

function onSubscriptionMessage(action, subscription)
{
  let element = findSubscriptionElement(subscription);

  switch (action)
  {
    case "disabled":
    case "downloading":
    case "downloadStatus":
    case "homepage":
    case "lastDownload":
    case "title":
      if (element)
        updateSubscriptionInfo(element, subscription);
      break;
    case "added":
      if (subscription.url.indexOf("~user") == 0)
        convertSpecialSubscription(subscription);
      else if (subscription.url == acceptableAdsUrl)
        $("#acceptableAds").prop("checked", true);
      else if (!element)
        addSubscriptionEntry(subscription);
      break;
    case "removed":
      if (subscription.url == acceptableAdsUrl)
        $("#acceptableAds").prop("checked", false);
      else if (element)
        element.parentNode.removeChild(element);
      break;
  }
}

function onPrefMessage(key, value)
{
  switch (key)
  {
    case "notifications_showui":
      document.getElementById(
        "shouldShowNotificationsContainer"
      ).hidden = !value;
      return;
    case "notifications_ignoredcategories":
      key = "shouldShowNotifications";
      value = value.indexOf("*") == -1;
      break;
  }
  let checkbox = document.getElementById(key);
  if (checkbox)
    checkbox.checked = value;
}

function onFilterMessage(action, filter)
{
  switch (action)
  {
    case "loaded":
      reloadFilters();
      break;
    case "added":
      if (whitelistedDomainRegexp.test(filter.text))
        appendToListBox("excludedDomainsBox", RegExp.$1);
      else
        appendToListBox("userFiltersBox", filter.text);
      break;
    case "removed":
      if (whitelistedDomainRegexp.test(filter.text))
        removeFromListBox("excludedDomainsBox", RegExp.$1);
      else
        removeFromListBox("userFiltersBox", filter.text);
      break;
  }
}

// Add a filter string to the list box.
function appendToListBox(boxId, text)
{
  // Note: document.createElement("option") is unreliable in Opera
  let elt = new Option();
  elt.text = text;
  elt.value = text;
  document.getElementById(boxId).appendChild(elt);
}

// Remove a filter string from a list box.
function removeFromListBox(boxId, text)
{
  let list = document.getElementById(boxId);
  // Edge does not support CSS.escape yet:
  // https://developer.microsoft.com/en-us/microsoft-edge/platform/issues/101410/
  quoteCSS(text, escapedCSS =>
  {
    let selector = "option[value=" + escapedCSS + "]";
    for (let option of list.querySelectorAll(selector))
      list.removeChild(option);
  });
}

function addWhitelistDomain(event)
{
  event.preventDefault();

  let domain = document.getElementById(
    "newWhitelistDomain"
  ).value.replace(/\s/g, "");
  document.getElementById("newWhitelistDomain").value = "";
  if (!domain)
    return;

  let filterText = "@@||" + domain + "^$document";
  addFilter(filterText);
}

// Adds filter text that user typed to the selection box
function addTypedFilter(event)
{
  event.preventDefault();

  let element = document.getElementById("newFilter");
  addFilter(element.value, errors =>
  {
    if (errors.length > 0)
      alert(errors.join("\n"));
    else
      element.value = "";
  });
}

// Removes currently selected whitelisted domains
function removeSelectedExcludedDomain(event)
{
  event.preventDefault();
  let remove = [];
  for (let option of document.getElementById("excludedDomainsBox").options)
  {
    if (option.selected)
      remove.push(option.value);
  }
  if (!remove.length)
    return;

  for (let domain of remove)
    removeFilter("@@||" + domain + "^$document");
}

// Removes all currently selected filters
function removeSelectedFilters(event)
{
  event.preventDefault();
  let options = document.querySelectorAll("#userFiltersBox > option:checked");
  for (let option of options)
    removeFilter(option.value);
}

// Shows raw filters box and fills it with the current user filters
function toggleFiltersInRawFormat(event)
{
  event.preventDefault();

  let rawFilters = document.getElementById("rawFilters");
  let filters = [];

  if (rawFilters.style.display != "table-row")
  {
    rawFilters.style.display = "table-row";
    for (let option of document.getElementById("userFiltersBox").options)
      filters.push(option.value);
  }
  else
  {
    rawFilters.style.display = "none";
  }

  document.getElementById("rawFiltersText").value = filters.join("\n");
}

// Imports filters in the raw text box
function importRawFiltersText()
{
  let text = document.getElementById("rawFiltersText").value;

  importRawFilters(text, true, errors =>
  {
    if (errors.length > 0)
      alert(errors.join("\n"));
    else
      $("#rawFilters").hide();
  });
}

// Called when user explicitly requests filter list updates
function updateFilterLists()
{
  // Without the URL parameter this will update all subscriptions
  updateSubscription();
}

// Adds a subscription entry to the UI.
function addSubscriptionEntry(subscription)
{
  let template = document.getElementById("subscriptionTemplate");
  let element = template.cloneNode(true);
  element.removeAttribute("id");
  element._subscription = subscription;

  let removeButton = element.getElementsByClassName(
    "subscriptionRemoveButton"
  )[0];
  removeButton.setAttribute("title", removeButton.textContent);
  removeButton.textContent = "\xD7";
  removeButton.addEventListener("click", () =>
  {
    if (!confirm(i18n.getMessage("global_remove_subscription_warning")))
      return;

    removeSubscription(subscription.url);
  }, false);

  getPref("additional_subscriptions", additionalSubscriptions =>
  {
    if (additionalSubscriptions.includes(subscription.url))
      removeButton.style.visibility = "hidden";
  });

  let enabled = element.getElementsByClassName("subscriptionEnabled")[0];
  enabled.addEventListener("click", () =>
  {
    subscription.disabled = !subscription.disabled;
    toggleSubscription(subscription.url, true);
  }, false);

  updateSubscriptionInfo(element);

  document.getElementById("filterLists").appendChild(element);
}

function setLinks(id, ...args)
{
  let element = document.getElementById(id);
  if (!element)
    return;

  let links = element.getElementsByTagName("a");
  for (let i = 0; i < links.length; i++)
  {
    if (typeof args[i] == "string")
    {
      links[i].href = args[i];
      links[i].setAttribute("target", "_blank");
    }
    else if (typeof args[i] == "function")
    {
      links[i].href = "javascript:void(0);";
      links[i].addEventListener("click", args[i], false);
    }
  }
}

ext.onMessage.addListener(message =>
{
  switch (message.type)
  {
    case "app.respond":
      switch (message.action)
      {
        case "addSubscription":
          let subscription = message.args[0];
          startSubscriptionSelection(subscription.title, subscription.url);
          break;
        case "focusSection":
          for (let tab of document.getElementsByClassName("ui-tabs-panel"))
          {
            let found = tab.querySelector(
              "[data-section='" + message.args[0] + "']"
            );
            if (!found)
              continue;

            let previous = document.getElementsByClassName("focused");
            if (previous.length > 0)
              previous[0].classList.remove("focused");

            let index = $("[href='#" + tab.id + "']").parent().index();
            $("#tabs").tabs("select", index);
            found.classList.add("focused");
          }
          break;
      }
      break;
    case "filters.respond":
      onFilterMessage(message.action, message.args[0]);
      break;
    case "prefs.respond":
      onPrefMessage(message.action, message.args[0]);
      break;
    case "subscriptions.respond":
      onSubscriptionMessage(message.action, message.args[0]);
      break;
  }
});

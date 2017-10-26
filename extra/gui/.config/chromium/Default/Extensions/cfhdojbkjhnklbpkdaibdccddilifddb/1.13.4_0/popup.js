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

const {require} = ext.backgroundPage.getWindow();

const {Filter} = require("filterClasses");
const {FilterStorage} = require("filterStorage");
const {Prefs} = require("prefs");
const {checkWhitelisted} = require("whitelisting");
const {getDecodedHostname} = require("url");

let page = null;

function onLoad()
{
  ext.pages.query({active: true, lastFocusedWindow: true}, pages =>
  {
    page = pages[0];

    // Mark page as 'local' or 'nohtml' to hide non-relevant elements
    if (!page || (page.url.protocol != "http:" &&
                  page.url.protocol != "https:"))
      document.body.classList.add("local");
    else if (!require("filterComposer").isPageReady(page))
    {
      document.body.classList.add("nohtml");
      require("messaging").getPort(window).on(
        "composer.ready", (message, sender) =>
        {
          if (sender.page.id == page.id)
            document.body.classList.remove("nohtml");
        }
      );
    }

    // Ask content script whether clickhide is active. If so, show
    // cancel button.  If that isn't the case, ask background.html
    // whether it has cached filters. If so, ask the user whether she
    // wants those filters. Otherwise, we are in default state.
    if (page)
    {
      if (checkWhitelisted(page))
        document.body.classList.add("disabled");

      page.sendMessage({type: "composer.content.getState"}, response =>
      {
        if (response && response.active)
          document.body.classList.add("clickhide-active");
      });
    }
  });

  document.getElementById("enabled").addEventListener(
    "click", toggleEnabled, false
  );
  document.getElementById("clickhide").addEventListener(
    "click", activateClickHide, false
  );
  document.getElementById("clickhide-cancel").addEventListener(
    "click", cancelClickHide, false
  );
  document.getElementById("options").addEventListener("click", () =>
  {
    ext.showOptions();
  }, false);

  // Set up collapsing of menu items
  for (let collapser of document.getElementsByClassName("collapse"))
  {
    collapser.addEventListener("click", toggleCollapse, false);
    if (!Prefs[collapser.dataset.option])
    {
      document.getElementById(
        collapser.dataset.collapsable
      ).classList.add("collapsed");
    }
  }
}

function toggleEnabled()
{
  let disabled = document.body.classList.toggle("disabled");
  if (disabled)
  {
    let host = getDecodedHostname(page.url).replace(/^www\./, "");
    let filter = Filter.fromText("@@||" + host + "^$document");
    if (filter.subscriptions.length && filter.disabled)
      filter.disabled = false;
    else
    {
      filter.disabled = false;
      FilterStorage.addFilter(filter);
    }
  }
  else
  {
    // Remove any exception rules applying to this URL
    let filter = checkWhitelisted(page);
    while (filter)
    {
      FilterStorage.removeFilter(filter);
      if (filter.subscriptions.length)
        filter.disabled = true;
      filter = checkWhitelisted(page);
    }
  }
}

function activateClickHide()
{
  document.body.classList.add("clickhide-active");
  page.sendMessage({type: "composer.content.startPickingElement"});

  // Close the popup after a few seconds, so user doesn't have to
  activateClickHide.timeout = window.setTimeout(ext.closePopup, 5000);
}

function cancelClickHide()
{
  if (activateClickHide.timeout)
  {
    window.clearTimeout(activateClickHide.timeout);
    activateClickHide.timeout = null;
  }
  document.body.classList.remove("clickhide-active");
  page.sendMessage({type: "composer.content.finished"});
}

function toggleCollapse(event)
{
  let collapser = event.currentTarget;
  Prefs[collapser.dataset.option] = !Prefs[collapser.dataset.option];
  collapser.parentNode.classList.toggle("collapsed");
}

document.addEventListener("DOMContentLoaded", onLoad, false);

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

let lastFilterQuery = null;

function generateFilter(request, domainSpecific)
{
  let filter = request.url.replace(/^[\w-]+:\/+(?:www\.)?/, "||");
  let options = [];

  if (request.type == "POPUP")
  {
    options.push("popup");

    if (request.url == "about:blank")
      domainSpecific = true;
  }

  if (domainSpecific)
    options.push("domain=" + request.docDomain);

  if (options.length > 0)
    filter += "$" + options.join(",");

  return filter;
}

function createActionButton(action, label, filter)
{
  let button = document.createElement("span");

  button.textContent = label;
  button.classList.add("action");

  button.addEventListener("click", () =>
  {
    ext.backgroundPage.sendMessage({
      type: "filters." + action,
      text: filter
    });
  }, false);

  return button;
}

function createRecord(request, filter, template)
{
  let row = document.importNode(template, true);
  row.dataset.type = request.type;

  row.querySelector(".domain").textContent = request.docDomain;
  row.querySelector(".type").textContent = request.type;

  let urlElement = row.querySelector(".url");
  let actionWrapper = row.querySelector(".action-wrapper");

  if (request.url)
  {
    urlElement.textContent = request.url;

    if (request.type != "POPUP")
    {
      urlElement.classList.add("resourceLink");
      urlElement.addEventListener("click", () =>
      {
        ext.devtools.panels.openResource(request.url);
      }, false);
    }
  }

  if (filter)
  {
    let filterElement = row.querySelector(".filter");
    let originElement = row.querySelector(".origin");

    filterElement.textContent = filter.text;
    row.dataset.state = filter.whitelisted ? "whitelisted" : "blocked";

    if (filter.subscription)
      originElement.textContent = filter.subscription;
    else
    {
      if (filter.userDefined)
        originElement.textContent = "user-defined";
      else
        originElement.textContent = "unnamed subscription";

      originElement.classList.add("unnamed");
    }

    if (!filter.whitelisted && request.type != "ELEMHIDE")
    {
      actionWrapper.appendChild(createActionButton(
        "add", "Add exception", "@@" + generateFilter(request, false)
      ));
    }

    if (filter.userDefined)
    {
      actionWrapper.appendChild(createActionButton(
        "remove", "Remove rule", filter.text
      ));
    }
  }
  else
  {
    actionWrapper.appendChild(createActionButton(
      "add", "Block item", generateFilter(request, request.specificOnly)
    ));
  }

  if (lastFilterQuery && shouldFilterRow(row, lastFilterQuery))
    row.classList.add("filtered-by-search");

  return row;
}

function shouldFilterRow(row, query)
{
  let elementsToSearch = [
    row.getElementsByClassName("url"),
    row.getElementsByClassName("filter"),
    row.getElementsByClassName("origin"),
    row.getElementsByClassName("type")
  ];

  for (let elements of elementsToSearch)
  {
    for (let element of elements)
    {
      if (element.innerText.search(query) != -1)
        return false;
    }
  }
  return true;
}

function performSearch(table, query)
{
  for (let row of table.rows)
  {
    if (shouldFilterRow(row, query))
      row.classList.add("filtered-by-search");
    else
      row.classList.remove("filtered-by-search");
  }
}

function cancelSearch(table)
{
  for (let row of table.rows)
    row.classList.remove("filtered-by-search");
}

document.addEventListener("DOMContentLoaded", () =>
{
  let container = document.getElementById("items");
  let table = container.querySelector("tbody");
  let template = document.querySelector("template").content.firstElementChild;

  document.getElementById("reload").addEventListener("click", () =>
  {
    ext.devtools.inspectedWindow.reload();
  }, false);

  document.getElementById("filter-state").addEventListener("change", (event) =>
  {
    container.dataset.filterState = event.target.value;
  }, false);

  document.getElementById("filter-type").addEventListener("change", (event) =>
  {
    container.dataset.filterType = event.target.value;
  }, false);

  ext.onMessage.addListener((message) =>
  {
    switch (message.type)
    {
      case "add-record":
        table.appendChild(createRecord(message.request, message.filter,
                                       template));
        break;

      case "update-record":
        let oldRow = table.getElementsByTagName("tr")[message.index];
        let newRow = createRecord(message.request, message.filter, template);
        oldRow.parentNode.replaceChild(newRow, oldRow);
        newRow.classList.add("changed");
        container.classList.add("has-changes");
        break;

      case "remove-record":
        let row = table.getElementsByTagName("tr")[message.index];
        row.parentNode.removeChild(row);
        container.classList.add("has-changes");
        break;

      case "reset":
        table.innerHTML = "";
        container.classList.remove("has-changes");
        break;
    }
  });

  window.addEventListener("message", (event) =>
  {
    switch (event.data.type)
    {
      case "performSearch":
        performSearch(table, event.data.queryString);
        lastFilterQuery = event.data.queryString;
        break;
      case "cancelSearch":
        cancelSearch(table);
        lastFilterQuery = null;
        break;
    }
  });

  // Since Chrome 54 the themeName is accessible, for earlier versions we must
  // assume the default theme is being used.
  // https://bugs.chromium.org/p/chromium/issues/detail?id=608869
  let theme = chrome.devtools.panels.themeName || "default";
  document.body.classList.add(theme);
}, false);

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

// This variable should no longer be necessary once options.js in Chrome
// accesses ext.i18n directly.
let {i18n} = ext;

// Getting UI locale cannot be done synchronously on Firefox,
// requires messaging the background page. For Chrome and Safari,
// we could get the UI locale here, but would need to duplicate
// the logic implemented in Utils.appLocale.
ext.backgroundPage.sendMessage(
  {
    type: "app.get",
    what: "localeInfo"
  },
  (localeInfo) =>
  {
    document.documentElement.lang = localeInfo.locale;
    document.documentElement.dir = localeInfo.bidiDir;
  }
);

// Inserts i18n strings into matching elements. Any inner HTML already
// in the element is parsed as JSON and used as parameters to
// substitute into placeholders in the i18n message.
ext.i18n.setElementText = function(element, stringName, args)
{
  function processString(str, currentElement)
  {
    let match = /^(.*?)<(a|strong)>(.*?)<\/\2>(.*)$/.exec(str);
    if (match)
    {
      processString(match[1], currentElement);

      let e = document.createElement(match[2]);
      processString(match[3], e);
      currentElement.appendChild(e);

      processString(match[4], currentElement);
    }
    else
      currentElement.appendChild(document.createTextNode(str));
  }

  while (element.lastChild)
    element.removeChild(element.lastChild);
  processString(ext.i18n.getMessage(stringName, args), element);
};

// Loads i18n strings
function loadI18nStrings()
{
  function addI18nStringsToElements(containerElement)
  {
    let elements = containerElement.querySelectorAll("[class^='i18n_']");
    for (let node of elements)
    {
      let args = JSON.parse("[" + node.textContent + "]");
      if (args.length == 0)
        args = null;

      let {className} = node;
      if (className instanceof SVGAnimatedString)
        className = className.animVal;
      let stringName = className.split(/\s/)[0].substring(5);

      ext.i18n.setElementText(node, stringName, args);
    }
  }
  addI18nStringsToElements(document);
  // Content of Template is not rendered on runtime so we need to add
  // translation strings for each Template documentFragment content
  // individually.
  for (let template of document.querySelectorAll("template"))
    addI18nStringsToElements(template.content);
}

// Provides a more readable string of the current date and time
function i18nTimeDateStrings(when)
{
  let d = new Date(when);
  let timeString = d.toLocaleTimeString();

  let now = new Date();
  if (d.toDateString() == now.toDateString())
    return [timeString];
  return [timeString, d.toLocaleDateString()];
}

// Formats date string to ["YYYY-MM-DD", "mm:ss"] format
function i18nFormatDateTime(when)
{
  let date = new Date(when);
  let dateParts = [date.getFullYear(), date.getMonth() + 1, date.getDate(),
                   date.getHours(), date.getMinutes()];

  dateParts = dateParts.map(
    (datePart) => datePart < 10 ? "0" + datePart : datePart
  );

  return [dateParts.splice(0, 3).join("-"), dateParts.join(":")];
}

// Fill in the strings as soon as possible
window.addEventListener("DOMContentLoaded", loadI18nStrings, true);

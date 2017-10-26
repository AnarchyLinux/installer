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

require.modules["content_elemHideEmulation"] = function(module, exports)
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

const {filterToRegExp, splitSelector} = require("common");

let MIN_INVOCATION_INTERVAL = 3000;
const MAX_SYNCHRONOUS_PROCESSING_TIME = 50;
const abpSelectorRegexp = /:-abp-([\w-]+)\(/i;

/** Return position of node from parent.
 * @param {Node} node the node to find the position of.
 * @return {number} One-based index like for :nth-child(), or 0 on error.
 */
function positionInParent(node)
{
  let {children} = node.parentNode;
  for (let i = 0; i < children.length; i++)
    if (children[i] == node)
      return i + 1;
  return 0;
}

function makeSelector(node, selector)
{
  if (node == null)
    return null;
  if (!node.parentElement)
  {
    let newSelector = ":root";
    if (selector)
      newSelector += " > " + selector;
    return newSelector;
  }
  let idx = positionInParent(node);
  if (idx > 0)
  {
    let newSelector = `${node.tagName}:nth-child(${idx})`;
    if (selector)
      newSelector += " > " + selector;
    return makeSelector(node.parentElement, newSelector);
  }

  return selector;
}

function parseSelectorContent(content, startIndex)
{
  let parens = 1;
  let quote = null;
  let i = startIndex;
  for (; i < content.length; i++)
  {
    let c = content[i];
    if (c == "\\")
    {
      // Ignore escaped characters
      i++;
    }
    else if (quote)
    {
      if (c == quote)
        quote = null;
    }
    else if (c == "'" || c == '"')
      quote = c;
    else if (c == "(")
      parens++;
    else if (c == ")")
    {
      parens--;
      if (parens == 0)
        break;
    }
  }

  if (parens > 0)
    return null;
  return {text: content.substring(startIndex, i), end: i};
}

/** Stringified style objects
 * @typedef {Object} StringifiedStyle
 * @property {string} style CSS style represented by a string.
 * @property {string[]} subSelectors selectors the CSS properties apply to.
 */

/**
 * Produce a string representation of the stylesheet entry.
 * @param {CSSStyleRule} rule the CSS style rule.
 * @return {StringifiedStyle} the stringified style.
 */
function stringifyStyle(rule)
{
  let styles = [];
  for (let i = 0; i < rule.style.length; i++)
  {
    let property = rule.style.item(i);
    let value = rule.style.getPropertyValue(property);
    let priority = rule.style.getPropertyPriority(property);
    styles.push(`${property}: ${value}${priority ? " !" + priority : ""};`);
  }
  styles.sort();
  return {
    style: styles.join(" "),
    subSelectors: splitSelector(rule.selectorText)
  };
}

function* evaluate(chain, index, prefix, subtree, styles)
{
  if (index >= chain.length)
  {
    yield prefix;
    return;
  }
  for (let [selector, element] of
       chain[index].getSelectors(prefix, subtree, styles))
  {
    if (selector == null)
      yield null;
    else
      yield* evaluate(chain, index + 1, selector, element, styles);
  }
  // Just in case the getSelectors() generator above had to run some heavy
  // document.querySelectorAll() call which didn't produce any results, make
  // sure there is at least one point where execution can pause.
  yield null;
}

function PlainSelector(selector)
{
  this._selector = selector;
}

PlainSelector.prototype = {
  /**
   * Generator function returning a pair of selector
   * string and subtree.
   * @param {string} prefix the prefix for the selector.
   * @param {Node} subtree the subtree we work on.
   * @param {StringifiedStyle[]} styles the stringified style objects.
   */
  *getSelectors(prefix, subtree, styles)
  {
    yield [prefix + this._selector, subtree];
  }
};

const incompletePrefixRegexp = /[\s>+~]$/;
const relativeSelectorRegexp = /^[>+~]/;

function HasSelector(selectors)
{
  this._innerSelectors = selectors;
}

HasSelector.prototype = {
  requiresHiding: true,

  get dependsOnStyles()
  {
    return this._innerSelectors.some(selector => selector.dependsOnStyles);
  },

  *getSelectors(prefix, subtree, styles)
  {
    for (let element of this.getElements(prefix, subtree, styles))
      yield [makeSelector(element, ""), element];
  },

  /**
   * Generator function returning selected elements.
   * @param {string} prefix the prefix for the selector.
   * @param {Node} subtree the subtree we work on.
   * @param {StringifiedStyle[]} styles the stringified style objects.
   */
  *getElements(prefix, subtree, styles)
  {
    let actualPrefix = (!prefix || incompletePrefixRegexp.test(prefix)) ?
        prefix + "*" : prefix;
    let elements = subtree.querySelectorAll(actualPrefix);
    for (let element of elements)
    {
      let iter = evaluate(this._innerSelectors, 0, "", element, styles);
      for (let selector of iter)
      {
        if (selector == null)
        {
          yield null;
          continue;
        }
        if (relativeSelectorRegexp.test(selector))
          selector = ":scope" + selector;
        try
        {
          if (element.querySelector(selector))
            yield element;
        }
        catch (e)
        {
          // :scope isn't supported on Edge, ignore error caused by it.
        }
      }
      yield null;
    }
  }
};

function ContainsSelector(textContent)
{
  this._text = textContent;
}

ContainsSelector.prototype = {
  requiresHiding: true,

  *getSelectors(prefix, subtree, stylesheet)
  {
    for (let element of this.getElements(prefix, subtree, stylesheet))
      yield [makeSelector(element, ""), subtree];
  },

  *getElements(prefix, subtree, stylesheet)
  {
    let actualPrefix = (!prefix || incompletePrefixRegexp.test(prefix)) ?
        prefix + "*" : prefix;
    let elements = subtree.querySelectorAll(actualPrefix);

    for (let element of elements)
    {
      if (element.textContent.includes(this._text))
        yield element;
      else
        yield null;
    }
  }
};

function PropsSelector(propertyExpression)
{
  let regexpString;
  if (propertyExpression.length >= 2 && propertyExpression[0] == "/" &&
      propertyExpression[propertyExpression.length - 1] == "/")
  {
    regexpString = propertyExpression.slice(1, -1)
      .replace("\\x7B ", "{").replace("\\x7D ", "}");
  }
  else
    regexpString = filterToRegExp(propertyExpression);

  this._regexp = new RegExp(regexpString, "i");
}

PropsSelector.prototype = {
  preferHideWithSelector: true,
  dependsOnStyles: true,

  *findPropsSelectors(styles, prefix, regexp)
  {
    for (let style of styles)
      if (regexp.test(style.style))
        for (let subSelector of style.subSelectors)
        {
          if (subSelector.startsWith("*") &&
              !incompletePrefixRegexp.test(prefix))
          {
            subSelector = subSelector.substr(1);
          }
          let idx = subSelector.lastIndexOf("::");
          if (idx != -1)
            subSelector = subSelector.substr(0, idx);
          yield prefix + subSelector;
        }
  },

  *getSelectors(prefix, subtree, styles)
  {
    for (let selector of this.findPropsSelectors(styles, prefix, this._regexp))
      yield [selector, subtree];
  }
};

function isSelectorHidingOnlyPattern(pattern)
{
  return pattern.selectors.some(s => s.preferHideWithSelector) &&
    !pattern.selectors.some(s => s.requiresHiding);
}

function ElemHideEmulation(window, getFiltersFunc, addSelectorsFunc,
                           hideElemsFunc)
{
  this.window = window;
  this.getFiltersFunc = getFiltersFunc;
  this.addSelectorsFunc = addSelectorsFunc;
  this.hideElemsFunc = hideElemsFunc;
  this.observer = new window.MutationObserver(this.observe.bind(this));
}

ElemHideEmulation.prototype = {
  isSameOrigin(stylesheet)
  {
    try
    {
      return new URL(stylesheet.href).origin == this.window.location.origin;
    }
    catch (e)
    {
      // Invalid URL, assume that it is first-party.
      return true;
    }
  },

  /** Parse the selector
   * @param {string} selector the selector to parse
   * @return {Array} selectors is an array of objects,
   * or null in case of errors.
   */
  parseSelector(selector)
  {
    if (selector.length == 0)
      return [];

    let match = abpSelectorRegexp.exec(selector);
    if (!match)
      return [new PlainSelector(selector)];

    let selectors = [];
    if (match.index > 0)
      selectors.push(new PlainSelector(selector.substr(0, match.index)));

    let startIndex = match.index + match[0].length;
    let content = parseSelectorContent(selector, startIndex);
    if (!content)
    {
      this.window.console.error(
        new SyntaxError("Failed to parse Adblock Plus " +
                        `selector ${selector} ` +
                        "due to unmatched parentheses."));
      return null;
    }
    if (match[1] == "properties")
      selectors.push(new PropsSelector(content.text));
    else if (match[1] == "has")
    {
      let hasSelectors = this.parseSelector(content.text);
      if (hasSelectors == null)
        return null;
      selectors.push(new HasSelector(hasSelectors));
    }
    else if (match[1] == "contains")
      selectors.push(new ContainsSelector(content.text));
    else
    {
      // this is an error, can't parse selector.
      this.window.console.error(
        new SyntaxError("Failed to parse Adblock Plus " +
                        `selector ${selector}, invalid ` +
                        `pseudo-class :-abp-${match[1]}().`));
      return null;
    }

    let suffix = this.parseSelector(selector.substr(content.end + 1));
    if (suffix == null)
      return null;

    selectors.push(...suffix);

    if (selectors.length == 1 && selectors[0] instanceof ContainsSelector)
    {
      this.window.console.error(
        new SyntaxError("Failed to parse Adblock Plus " +
                        `selector ${selector}, can't ` +
                        "have a lonely :-abp-contains()."));
      return null;
    }
    return selectors;
  },

  /**
   * Processes the current document and applies all rules to it.
   * @param {CSSStyleSheet[]} [stylesheets]
   *    The list of new stylesheets that have been added to the document and
   *    made reprocessing necessary. This parameter shouldn't be passed in for
   *    the initial processing, all of document's stylesheets will be considered
   *    then and all rules, including the ones not dependent on styles.
   * @param {function} [done]
   *    Callback to call when done.
   */
  _addSelectors(stylesheets, done)
  {
    let selectors = [];
    let selectorFilters = [];

    let elements = [];
    let elementFilters = [];

    let cssStyles = [];

    let stylesheetOnlyChange = !!stylesheets;
    if (!stylesheets)
      stylesheets = this.window.document.styleSheets;

    // Chrome < 51 doesn't have an iterable StyleSheetList
    // https://issues.adblockplus.org/ticket/5381
    for (let i = 0; i < stylesheets.length; i++)
    {
      let stylesheet = stylesheets[i];
      // Explicitly ignore third-party stylesheets to ensure consistent behavior
      // between Firefox and Chrome.
      if (!this.isSameOrigin(stylesheet))
        continue;

      let rules = stylesheet.cssRules;
      if (!rules)
        continue;

      for (let rule of rules)
      {
        if (rule.type != rule.STYLE_RULE)
          continue;

        cssStyles.push(stringifyStyle(rule));
      }
    }

    let {document} = this.window;

    let patterns = this.patterns.slice();
    let pattern = null;
    let generator = null;

    let processPatterns = () =>
    {
      let cycleStart = this.window.performance.now();

      if (!pattern)
      {
        if (!patterns.length)
        {
          this.addSelectorsFunc(selectors, selectorFilters);
          this.hideElemsFunc(elements, elementFilters);
          if (typeof done == "function")
            done();
          return;
        }

        pattern = patterns.shift();

        if (stylesheetOnlyChange &&
            !pattern.selectors.some(selector => selector.dependsOnStyles))
        {
          pattern = null;
          return processPatterns();
        }
        generator = evaluate(pattern.selectors, 0, "", document, cssStyles);
      }
      for (let selector of generator)
      {
        if (selector != null)
        {
          if (isSelectorHidingOnlyPattern(pattern))
          {
            selectors.push(selector);
            selectorFilters.push(pattern.text);
          }
          else
          {
            for (let element of document.querySelectorAll(selector))
            {
              elements.push(element);
              elementFilters.push(pattern.text);
            }
          }
        }
        if (this.window.performance.now() -
            cycleStart > MAX_SYNCHRONOUS_PROCESSING_TIME)
        {
          this.window.setTimeout(processPatterns, 0);
          return;
        }
      }
      pattern = null;
      return processPatterns();
    };

    processPatterns();
  },

  // This property is only used in the tests
  // to shorten the invocation interval
  get MIN_INVOCATION_INTERVAL()
  {
    return MIN_INVOCATION_INTERVAL;
  },

  set MIN_INVOCATION_INTERVAL(interval)
  {
    MIN_INVOCATION_INTERVAL = interval;
  },

  _filteringInProgress: false,
  _lastInvocation: -MIN_INVOCATION_INTERVAL,
  _scheduledProcessing: null,

  /**
   * Re-run filtering either immediately or queued.
   * @param {CSSStyleSheet[]} [stylesheets]
   *    new stylesheets to be processed. This parameter should be omitted
   *    for DOM modification (full reprocessing required).
   */
  queueFiltering(stylesheets)
  {
    let completion = () =>
    {
      this._lastInvocation = this.window.performance.now();
      this._filteringInProgress = false;
      if (this._scheduledProcessing)
      {
        let newStylesheets = this._scheduledProcessing.stylesheets;
        this._scheduledProcessing = null;
        this.queueFiltering(newStylesheets);
      }
    };

    if (this._scheduledProcessing)
    {
      if (!stylesheets)
        this._scheduledProcessing.stylesheets = null;
      else if (this._scheduledProcessing.stylesheets)
        this._scheduledProcessing.stylesheets.push(...stylesheets);
    }
    else if (this._filteringInProgress)
    {
      this._scheduledProcessing = {stylesheets};
    }
    else if (this.window.performance.now() -
             this._lastInvocation < MIN_INVOCATION_INTERVAL)
    {
      this._scheduledProcessing = {stylesheets};
      this.window.setTimeout(() =>
      {
        let newStylesheets = this._scheduledProcessing.stylesheets;
        this._filteringInProgress = true;
        this._scheduledProcessing = null;
        this._addSelectors(newStylesheets, completion);
      },
      MIN_INVOCATION_INTERVAL -
      (this.window.performance.now() - this._lastInvocation));
    }
    else
    {
      this._filteringInProgress = true;
      this._addSelectors(stylesheets, completion);
    }
  },

  onLoad(event)
  {
    let stylesheet = event.target.sheet;
    if (stylesheet)
      this.queueFiltering([stylesheet]);
  },

  observe(mutations)
  {
    this.queueFiltering();
  },

  apply()
  {
    this.getFiltersFunc(patterns =>
    {
      this.patterns = [];
      for (let pattern of patterns)
      {
        let selectors = this.parseSelector(pattern.selector);
        if (selectors != null && selectors.length > 0)
          this.patterns.push({selectors, text: pattern.text});
      }

      if (this.patterns.length > 0)
      {
        let {document} = this.window;
        this.queueFiltering();
        this.observer.observe(
          document,
          {
            childList: true,
            attributes: true,
            characterData: true,
            subtree: true
          }
        );
        document.addEventListener("load", this.onLoad.bind(this), true);
      }
    });
  }
};

exports.ElemHideEmulation = ElemHideEmulation;

return module.exports;
};


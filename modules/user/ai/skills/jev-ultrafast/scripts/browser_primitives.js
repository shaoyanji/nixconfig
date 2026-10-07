import fs from 'fs';
import os from 'os';
import { chromium } from 'playwright';

/**
 * Finds Windows chrome.exe (or msedge.exe) path.
 */
export function getChromiumPath() {
  if (process.env.CHROME_PATH && fs.existsSync(process.env.CHROME_PATH)) {
    return process.env.CHROME_PATH;
  }
  if (process.env.BH_CHROME_PATH && fs.existsSync(process.env.BH_CHROME_PATH)) {
    return process.env.BH_CHROME_PATH;
  }

  const isWindows = process.platform === 'win32';

  const candidates = isWindows
    ? [
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
        pathJoin(process.env.LOCALAPPDATA, 'Google\\Chrome\\Application\\chrome.exe'),
        'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe'
      ]
    : [
        '/mnt/c/Program Files/Google/Chrome/Application/chrome.exe',
        '/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe',
        '/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'
      ];

  for (const c of candidates) {
    if (c && fs.existsSync(c)) return c;
  }

  return undefined;
}

function pathJoin(base, sub) {
  if (!base) return '';
  return `${base}\\${sub}`;
}

/**
 * Launches a Playwright browser instance using Windows chrome.exe.
 */
export async function launchBrowser(options = {}) {
  const executablePath = getChromiumPath();
  const headless = options.headless !== undefined ? options.headless : true;

  const args = [
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-background-networking',
    ...(options.args || [])
  ];

  const launchOptions = {
    headless,
    args,
    ...(executablePath ? { executablePath } : {})
  };

  const browser = await chromium.launch(launchOptions);
  return browser;
}

/**
 * Observes the interactive elements on the page and builds an action space.
 */
export async function observePage(page, options = {}) {
  const maxActions = options.maxActions || 250;
  const textLimit = options.textLimit || 6000;

  const rawState = await page.evaluate(({ maxActions, textLimit }) => {
    if (!document.body) return null;
    const cache = window.__jevFast ||= { ids: new WeakMap(), nodes: new Map(), next: 1 };

    const idFor = el => {
      if (!cache.ids.has(el)) {
        const id = `e${cache.next++}`;
        cache.ids.set(el, id);
        el.dataset.jevActionId = id;
      }
      return cache.ids.get(el);
    };

    const safe = el => !['password', 'hidden'].includes(el.type);
    const visible = el => {
      if (el.closest('[aria-hidden="true"],[inert]')) return false;
      if (typeof el.checkVisibility === 'function' && !el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true })) return false;
      const rect = el.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0;
    };

    const name = (el, seen = new Set()) => {
      if (!el || seen.has(el)) return '';
      seen.add(el);
      const label = el.id ? document.querySelector(`label[for="${CSS.escape(el.id)}"]`) : null;
      return (el.getAttribute('aria-label') || label?.innerText || el.innerText || el.value || el.placeholder || el.title || '').trim().slice(0, 300);
    };

    const roles = ['button', 'link', 'checkbox', 'radio', 'switch', 'tab', 'menuitem', 'option', 'combobox', 'textbox', 'searchbox', 'spinbutton'];
    const selector = 'a[href],button,input,textarea,select,summary,[contenteditable="true"],' +
      roles.map(r => `[role="${r}"]`).join(',');

    const roleOf = el => {
      const explicit = el.getAttribute('role');
      if (roles.includes(explicit)) return explicit;
      if (el.tagName === 'BUTTON' || el.tagName === 'SUMMARY' || ['submit', 'button', 'reset'].includes(el.type)) return 'button';
      if (el.tagName === 'A') return 'link';
      if (el.tagName === 'SELECT') return 'combobox';
      if (el.tagName === 'TEXTAREA' || el.isContentEditable) return 'textbox';
      if (el.tagName === 'INPUT') {
        if (['checkbox', 'radio'].includes(el.type)) return el.type;
        if (el.type === 'search') return 'searchbox';
        if (el.type === 'number') return 'spinbutton';
        if (['text', 'email', 'url', 'tel'].includes(el.type)) return 'textbox';
      }
      return null;
    };

    const actions = [];
    for (const el of document.querySelectorAll(selector)) {
      if (!safe(el) || !visible(el) || el.disabled || el.getAttribute('aria-disabled') === 'true') continue;
      const rect = el.getBoundingClientRect();
      if (rect.bottom <= 0 || rect.top >= innerHeight) continue;

      const elementId = idFor(el);
      const role = roleOf(el);
      const label = name(el) || role || elementId;
      const base = {
        id: elementId,
        elementId,
        role,
        label,
        name: el.name || '',
        placeholder: el.placeholder || '',
        required: Boolean(el.required || el.getAttribute('aria-required') === 'true')
      };

      if (el.tagName === 'SELECT') {
        for (const opt of el.options) {
          if (opt.selected || opt.disabled) continue;
          actions.push({
            ...base,
            kind: 'select',
            label: `${base.label} → ${opt.label}`,
            value: opt.value,
            currentValue: el.value
          });
        }
      } else if (['textbox', 'searchbox', 'spinbutton'].includes(role) && !el.readOnly) {
        actions.push({ ...base, kind: 'fill', value: el.value || '' });
        if (el.getAttribute('role') === 'combobox' || el.tagName === 'INPUT') {
          actions.push({ ...base, kind: 'click', label: `Open ${base.label}` });
        }
      } else {
        actions.push({ ...base, kind: 'click', value: el.value || '', checked: el.checked });
      }
    }

    if (scrollY + innerHeight < document.documentElement.scrollHeight - 2) {
      actions.push({ id: 'scroll_down', kind: 'scroll', label: 'Scroll down' });
    }
    if (scrollY > 0) {
      actions.push({ id: 'scroll_up', kind: 'scroll', label: 'Scroll up' });
    }
    actions.push({ id: 'wait', kind: 'wait', label: 'Wait for page to update' });

    return {
      url: location.href,
      title: document.title,
      text: (document.body.innerText || '').slice(0, textLimit),
      actions: actions.slice(0, maxActions)
    };
  }, { maxActions, textLimit });

  return rawState;
}

/**
 * Builds indexed action space table and candidate target heads for TypeSafe Jev.
 */
export function buildActionSpace(actions = []) {
  const elements = [];
  const elementById = new Map();
  const targets = {};
  const controls = {};

  const operations = { click: 'CLICK', fill: 'TYPE_TEXT', select: 'SELECT' };

  for (const action of actions) {
    const kind = action.kind;
    if (!operations[kind]) {
      controls[action.id.toUpperCase()] = action;
      continue;
    }

    const elementId = action.elementId || action.id;
    let element = elementById.get(elementId);
    if (!element) {
      element = {
        index: String(elements.length + 1),
        id: elementId,
        role: action.role || 'unknown',
        label: action.label ? action.label.split(' → ')[0] : elementId,
        value: action.value || '',
        operations: []
      };
      if (action.required !== undefined) element.required = action.required;
      if (action.checked !== undefined) element.checked = action.checked;
      if (action.currentValue !== undefined) element.currentValue = action.currentValue;
      if (kind === 'select') element.options = [];
      elements.push(element);
      elementById.set(elementId, element);
    }

    const op = operations[kind];
    if (!element.operations.includes(op)) element.operations.push(op);

    let target = element.index;
    if (kind === 'select') {
      target = `${element.index}:${element.options.length + 1}`;
      element.options.push({ index: target, label: action.label, value: action.value });
    }

    if (!targets[op]) targets[op] = {};
    targets[op][target] = { ...action, target, elementIndex: element.index };
  }

  return { elements, targets, controls };
}

/**
 * Executes chosen action on the live Playwright page.
 */
export async function executeAction(page, decision, valueToType = null) {
  if (!decision || !decision.operation) {
    return { executed: false, reason: 'no_decision' };
  }

  const { operation, action } = decision;

  if (operation === 'DONE' || operation === 'BLOCKED') {
    return { executed: false, reason: operation.toLowerCase() };
  }

  if (operation === 'WAIT') {
    await page.waitForTimeout(500);
    return { executed: true, operation: 'WAIT' };
  }

  if (operation === 'SCROLL_DOWN') {
    await page.evaluate(() => window.scrollBy({ top: 560, behavior: 'instant' }));
    return { executed: true, operation: 'SCROLL_DOWN' };
  }

  if (operation === 'SCROLL_UP') {
    await page.evaluate(() => window.scrollBy({ top: -560, behavior: 'instant' }));
    return { executed: true, operation: 'SCROLL_UP' };
  }

  if (!action || !action.elementId) {
    return { executed: false, reason: 'target_not_observed' };
  }

  const locator = page.locator(`[data-jev-action-id="${action.elementId}"]`).first();
  const visible = await locator.isVisible().catch(() => false);
  if (!visible) {
    return { executed: false, reason: 'stale_target' };
  }

  if (operation === 'TYPE_TEXT') {
    if (valueToType === null || valueToType === undefined) {
      return { executed: false, reason: 'no_text_value_provided' };
    }
    await locator.fill(String(valueToType));
    return { executed: true, operation: 'TYPE_TEXT', actionId: action.elementId, typed: valueToType };
  }

  if (operation === 'SELECT') {
    await locator.selectOption(action.value);
    return { executed: true, operation: 'SELECT', actionId: action.elementId, selected: action.value };
  }

  if (operation === 'CLICK') {
    await locator.click();
    return { executed: true, operation: 'CLICK', actionId: action.elementId };
  }

  return { executed: false, reason: `unsupported_operation_${operation}` };
}

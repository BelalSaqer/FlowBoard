// @ts-check
const { test, expect } = require('@playwright/test');

// Flutter web renders the whole UI to a single <canvas> — there's no
// DOM tree for Playwright's usual text/role locators to find, so these
// checks lean on console-error absence (real regressions: a missing
// plugin registration, an uncaught exception, a bad Firebase config)
// plus a screenshot for visual review, rather than DOM assertions.

test('sign-in screen loads with no console errors', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });

  await page.goto('/', { waitUntil: 'networkidle' });
  // First paint of a Flutter web app takes a beat longer than
  // networkidle — give the engine time to attach and draw a frame.
  await page.waitForTimeout(2500);

  await page.screenshot({ path: 'test-results/sign-in.png' });

  expect(errors, `Console errors on load:\n${errors.join('\n')}`).toEqual([]);
});

// @ts-check
const { test, expect } = require('@playwright/test');

// Coordinates below match the sign-in screen's layout at this exact
// viewport size (see lib/screens/sign_in_screen.dart) — "Continue as
// Guest" sits centered near the bottom of the auth card. If this starts
// failing after a sign-in screen redesign, re-capture the coordinate
// from a fresh screenshot rather than guessing.
test.use({ viewport: { width: 400, height: 850 } });

test('guest sign-in reaches a populated demo board list', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));

  await page.goto('/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);

  await page.mouse.click(200, 425); // "Continue as Guest"
  await page.waitForTimeout(3000);

  await page.screenshot({ path: 'test-results/guest-boards.png' });

  expect(errors, `Console errors after guest sign-in:\n${errors.join('\n')}`).toEqual([]);
});

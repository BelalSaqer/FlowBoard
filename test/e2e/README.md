# FlowBoard E2E checks

Live-browser checks against the **deployed** app, complementing the offline
provider/widget tests in `test/*_test.dart`. These exist for the things unit
tests can't see: a real Firestore round trip, a real OAuth popup, a real
deep link — this project's most serious bugs so far were only caught this
way (see the "Testing Strategy" section of the project documentation).

Not wired into CI: they need a live deployed URL and download a real
Chromium browser, which doesn't fit a fast `flutter analyze && flutter test`
job. Run them manually after a deploy instead.

## Run

```
cd test/e2e
npm install
npx playwright install chromium   # first time only
npm test
```

Point at a different environment (e.g. a local `firebase serve` or hosting
preview channel) with:

```
FLOWBOARD_URL=http://localhost:5000 npm test
```

## Why coordinate clicks, not `page.getByText(...)`

Flutter web paints the entire UI onto a single `<canvas>` — there's no DOM
tree of buttons and labels for Playwright's normal locators to find. Each
spec instead clicks fixed pixel coordinates matched to a specific screen's
layout at a specific viewport size, and asserts on the *absence* of console
errors (a real signal: a missing plugin registration, an uncaught
exception, a misconfigured Firebase key) rather than on visible text. If a
spec starts failing after a layout change, re-capture the coordinate from a
fresh screenshot in `test-results/` rather than guessing.

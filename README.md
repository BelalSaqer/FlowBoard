# FlowBoard

A real-time collaborative task board — built with Flutter and Firebase as a
portfolio-grade engineering project. Every piece of "real-time" behavior
here is a genuine Firestore listener chain, not a simulated demo: drag a
card and another open tab moves it live; two people editing the same card
get a real conflict banner computed from actual concurrent writes; a
teammate's presence pill appears from a live heartbeat.

**Live app:** https://flowboard-app-7539.web.app

## Features

**Boards & tasks**
- Create, rename, recolor, and archive boards; drag-and-drop cards across
  To Do / In Progress / Done with fractional-index ordering
- Start from a template (Sprint board, Content calendar, Bug tracker) or
  blank
- Labels, due dates with overdue/due-soon indicators, subtasks, small image
  attachments, and a per-board activity log with a 7-day velocity chart
- Comments with `@mention` notifications and lightweight markdown
  (`**bold**`, `*italic*`, `` `code` ``, `[links](url)`)
- Multi-select bulk move/delete, and undoable task/board deletion

**Finding things**
- **My Tasks** — everything assigned to you across every board you're in
- Search plus priority, assignee, overdue, and due-soon filters, with
  named/saved filter combinations per board
- CSV export and import (round-trips losslessly)
- Keyboard shortcuts — `n` for a new task, `/` for search, `Esc` to close
  a sheet

**Real-time collaboration**
- Live presence and conflict detection (flags when someone else edited a
  card while you had it open)
- AI-assisted subtasks via the Gemini API (falls back to a static
  suggestion list with no key configured)

**Identity & sharing**
- Google, Apple, email/password, or guest sign-in, with account linking
  and clear recovery paths for Firebase's ambiguous credential errors
- Reserved `@usernames` (server-validated format, race-safe claims) and
  client-compressed avatar photo upload — no paid storage backend
- Three ways to invite: by email, by `@username`, or a shareable
  `/join/{boardId}` link
- Real per-board Owner/Editor/Viewer permissions enforced by Firestore
  Security Rules, not just hidden UI

**Polish**
- Notifications, light/dark/system theme, branded splash screen
- Installable PWA (filled-in manifest, real icons, registered service
  worker)
- Accessibility pass: tooltip/semantic labels on every icon-only button,
  priority-tag colors checked against WCAG AA contrast rather than assumed

## Tech stack

Flutter (Web + Android) · Riverpod · Firebase (Firestore, Auth, Hosting) ·
Google Gemini API

Deliberately built without any paid infrastructure — no Cloud Functions, no
Firebase Storage (now Blaze-only even for free-tier usage). Avatar photos
and task attachments are compressed client-side and stored inline; invite
links and permissions are enforced entirely through Firestore Security
Rules; saved filters live in local device storage.

## Getting started

```bash
flutter pub get

# Point at your own Firebase project
flutterfire configure

# Enable Google, Apple, Email/Password, and Anonymous sign-in
# in Firebase Console → Authentication → Sign-in method

firebase deploy --only firestore:rules

flutter run -d chrome --dart-define=GEMINI_API_KEY=your_key_here
```

## Testing

```bash
flutter analyze
flutter test
```

56 provider/widget tests run against `fake_cloud_firestore` and
`firebase_auth_mocks` — no live Firebase project needed. A separate
Playwright suite in [`test/e2e/`](test/e2e/) checks things unit tests can't
see (real OAuth popups, real deep links, real Firestore round trips)
against a live deployed URL; see that folder's README for how to run it.

## Deployment

```bash
flutter build web --release --dart-define=GEMINI_API_KEY=your_key_here
firebase deploy --only hosting
firebase deploy --only firestore:rules   # after any firestore.rules change
```

CI (`.github/workflows/ci.yml`) runs `flutter analyze`, `flutter test`, and
a release web build on every push and pull request.

## Project structure

```
lib/
├── data/        # Firestore ⇄ model mappers, CSV import/export, board
│                  templates, saved filters, rich-text parsing, demo seed
├── models/      # plain immutable data classes
├── providers/   # all Firestore/Auth logic (Riverpod)
├── screens/     # one file per full-page route
├── services/    # Gemini client, deep-link capture, web-only file I/O
├── theme/       # design tokens
└── widgets/     # reusable shared UI

test/            # provider/widget tests (offline, fake_cloud_firestore)
test/e2e/        # Playwright checks against the live deployed app
firestore.rules  # full security model — see the project documentation
```

## Known limitations

- **iOS**: builds for Web and Android only. The iOS project scaffold exists
  but has no `GoogleService-Info.plist` and was never Xcode-signed — Firebase
  wasn't configured for that platform (requires a Mac + Firebase Console
  access this project's environment doesn't have). Running
  `flutterfire configure` with iOS selected, on a Mac, should be enough to
  bring it up.
- **Gemini API key** is scoped by API restriction, not by HTTP referrer —
  current Gemini key types don't support referrer restriction. A backend
  proxy would close this gap but requires paid Cloud Functions.
- Avatar photos are capped at ~180 KB, task attachments at ~120 KB each
  (max 3 per task) — both stored inline on their document to avoid a paid
  storage backend.
- CSV import matches the "Assignee" column by exact display name against
  the board's current members; no match (or a blank cell) falls back to
  whoever ran the import, since a spreadsheet can't carry a real member id.
- Saved filters live in browser/device local storage, not Firestore — they
  don't follow you to a different device.

## Documentation

A full architecture, data-model, and security-rules writeup lives in
[`FlowBoard_Documentation.pdf`](FlowBoard_Documentation.pdf).

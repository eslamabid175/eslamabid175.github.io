---
name: run-app
description: Launch the app and look at it - Flutter web in a browser driven by the Playwright MCP, mobile on an Android emulator driven by the mobile MCP or Marionette (debug builds). Use for "run the app", "show me the screen", "check the change in the real app", screenshots, visual verification.
argument-hint: "[web|android] [screen or flow to check]"
---
Arguments: $ARGUMENTS

## Decide which API the app talks to first
Find the base URL constant. Rules:
- Reading screens against production only with the user's own login: the
  user types credentials in the opened browser/emulator; you never type or
  store production credentials.
- No write actions (save, delete, send, pay) against production unless the
  user asked for that exact action in this conversation.
- For anything that writes, use the dev API: `--dart-define=API_BASE_URL=<YOUR_DEV_API_URL>`
  if the app supports it; otherwise switch the constant locally, say so, and
  restore it before you finish (`git diff` must not show it).

## Web
1. `flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1` in the
   background; wait for "is being served at".
2. Playwright MCP: `browser_navigate` to `http://127.0.0.1:8080`.
3. Flutter web renders to a canvas. Enable the semantics tree before
   snapshots or role-based clicks:
   `browser_evaluate` with `() => document.querySelector('flt-semantics-placeholder')?.click()`.
   Otherwise work from screenshots and coordinates.

## Android
1. `emulator -list-avds`; `emulator -avd <name> -no-snapshot-save` in the
   background; wait until `adb devices` lists it as `device`.
2. `flutter run -d emulator-5554` in the background; note the VM service URI
   (`ws://127.0.0.1:<port>/<token>=/ws`) in the output.
3. Drive it:
   - **mobile MCP**: list devices, `mobile_list_elements_on_screen` (prefer it
     over screenshots), taps/typing, screenshots, device logs. Also handles
     system dialogs (permissions).
   - **Marionette MCP** (debug builds with the binding): `connect` with the VM
     service URI, `get_interactive_elements`, `tap`, `enter_text`,
     `scroll_to`, `take_screenshots`, `get_logs`, `hot_reload`. Needs
     `marionette_flutter` as a dev dependency and
     `MarionetteBinding.ensureInitialized()` behind `kDebugMode` in a debug
     entry point. Adding it is a repo change: ask first.
   - **Dart MCP**: connect it to the running app (`dtd` / `vm_service` with the
     URI from the `flutter run` output), then hot reload, runtime errors,
     widget inspector. (`launch_app` is off by default since Dart 3.12, so
     start the app with `flutter run` as above.)

## Finish
Stop the background `flutter run`/emulator you started (or tell the user they
are still running), restore any temporary URL switch, and report: target,
API, what was checked, screenshots, problems seen (with the log line).

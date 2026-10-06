---
paths:
  - "lib/**"
  - "test/**"
  - "patrol_test/**"
  - "packages/**/lib/**"
---
# Flutter app rules (loaded only when working on these paths)

Edit this file to match YOUR project. Delete rules that do not apply.

## Architecture
- Layers: `presentation -> domain <- data`. Widgets never import data
  sources, DTOs or DAOs. The domain layer has no Flutter, Dio, drift or
  Firebase imports.
- Feature-first folders: `lib/features/<feature>/{data,domain,presentation}`;
  shared code in `lib/core/`.
- Repositories return `<RESULT_TYPE>` (e.g. `Either<Failure, T>` /
  `Result<T>`) and never throw across a layer boundary.
- DI through `<DI_TOOL>` (get_it + injectable / riverpod providers). Register
  new classes the same way as their neighbours.

## State management (<STATE_MANAGEMENT>)
- One cubit/bloc/notifier per screen or flow; immutable states (freezed /
  sealed classes); no business logic in widgets.
- Never emit after close; cancel stream subscriptions in `close()`/`dispose`.
- Every async screen has loading, empty, error (with retry) and data states.

## UI
- Colours and text styles only from the theme (`Theme.of(context)` /
  `context.<extension>`), never raw `Colors.*` or hex in features.
- Use the shared widgets in `lib/core/widgets/` before writing new ones.
- RTL-safe: `EdgeInsetsDirectional`, `AlignmentDirectional`,
  `TextAlign.start/end` (if any supported locale is RTL).
- Every visible string comes from l10n, in every locale (see the l10n skill).
- Tap targets >= 48dp, `tooltip` on `IconButton`, no overflow at text
  scale 1.3.

## Networking
- One API client (`<API_CLIENT>`, e.g. Dio + retrofit). Base URL from
  `String.fromEnvironment('API_BASE_URL', defaultValue: '<YOUR_PROD_API_URL>')`
  so tests and E2E can target a dev API without code edits.
- Never log tokens, passwords or personal data.

## Generated code
- After changing any `part '*.g.dart'` / freezed / json / retrofit / drift /
  injectable input: `dart run build_runner build --delete-conflicting-outputs`.
- Never hand-edit generated files.

## Tests
- Unit tests for use cases/repositories/cubits (`bloc_test`, `mocktail`).
- Widget tests for complex widgets; Patrol E2E in `patrol_test/` on an
  emulator against a dev API only.

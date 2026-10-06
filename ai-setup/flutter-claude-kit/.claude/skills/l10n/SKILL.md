---
name: l10n
description: Add or change user-facing copy - .arb keys in the template and every locale with matching placeholders, flutter gen-l10n, parity check. Use whenever a UI string is added, renamed or reworded.
argument-hint: "<what copy to add or change>"
---
Request: $ARGUMENTS

1. Read `l10n.yaml` for `arb-dir`, `template-arb-file` and
   `output-dir`/`synthetic-package`.
2. Look for existing wording first:
   `grep -n '"<keyFragment>' <arb-dir>/*.arb`. Reuse a key only when the
   meaning is identical. Otherwise name it after the screen and role
   (`<feature><Element><Role>`, e.g. `checkoutPayButton`), like its
   neighbours.
3. Add the key to the template with an `@key` description and typed
   placeholders, then the same key with the same placeholders to EVERY other
   locale. No locale is left for later.
   - Numbers, money and dates arrive as placeholders and are formatted in
     Dart with the locale, never baked into the string.
   - Plurals/selects use standard ICU (`{count, plural, =0{...} one{...} other{...}}`)
     in every locale.
   - RTL locales: check how the string reads with embedded numbers/names.
4. `flutter gen-l10n` (commit the generated output if the repo does).
5. Use it through the repo's accessor (`AppLocalizations.of(context)!` or a
   `context.l10n` extension, whichever the surrounding code uses).
6. Gates: `python3 .claude/bin/check_arb_parity.py` and `flutter analyze`.
7. If a design/screen spec quotes the copy, update it in the same change.

Report the keys added or changed with the text per locale.

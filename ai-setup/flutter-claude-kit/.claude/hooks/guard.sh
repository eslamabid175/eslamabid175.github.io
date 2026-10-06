#!/usr/bin/env bash
# PreToolUse guard for Bash commands (matcher: Bash).
#
# Reads the hook JSON on stdin and answers:
#   deny -> printing credential files (keystores, key.properties, .env, service accounts)
#   ask  -> anything that publishes, rewrites git history, deletes recursively,
#           ships a build, or wipes app data on a device
# No output + exit 0 means "no opinion": the normal permission rules decide.
#
# "ask" shows a prompt even in auto/accept-edits mode. If that gets in your way,
# delete the categories you do not want (or the whole PreToolUse entry in
# .claude/settings.json) and rely on the deny rules there instead.
set -u
input=$(cat)

field() { # field .tool_input.command
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null
  else
    printf '%s' "$input" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for k in sys.argv[1].strip(".").split("."):
    d = d.get(k) if isinstance(d, dict) else None
print("" if d is None else d)' "$1" 2>/dev/null
  fi
}

cmd=$(field .tool_input.command)
[ -z "$cmd" ] && exit 0

decide() { # decide ask|deny "reason"  (reason must not contain double quotes)
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$2"
  exit 0
}
has() { printf '%s' "$cmd" | grep -Eiq -- "$1"; }
S='(^|[[:space:];|&(])'   # start of a command word

# 1. Credentials: never print them into the transcript.
READER="${S}(cat|less|more|head|tail|bat|grep|rg|sed|awk|strings|xxd|base64|cp|scp|source|\.)[[:space:]][^|;&]*"
if has "${READER}(key\.properties|\.jks|\.keystore|\.p12|\.pem|service-account[^[:space:]]*\.json|\.claude/local/)" \
  || { has "${READER}\.env([.][a-zA-Z]+)?([[:space:]]|$)" && ! has "\.env\.(example|sample|template)([[:space:]]|$)"; }; then
  decide deny "Credential/secret file: do not print it. Ask the user for the specific non-secret value you need."
fi

# 2. Git: publishing and history-destroying commands.
has "${S}git[[:space:]]+([-a-zA-Z]+[[:space:]]+)*push([[:space:]]|$)" \
  && decide ask "git push publishes commits. Confirm the branch and remote."
has "${S}git[[:space:]]+([-a-zA-Z]+[[:space:]]+)*(reset[[:space:]]+--hard|clean[[:space:]]+-[a-z]*f|checkout[[:space:]]+--[[:space:]]|checkout[[:space:]]+\.|restore[[:space:]]+(--staged[[:space:]]+)?\.|branch[[:space:]]+-D|rebase|commit[[:space:]]+--amend|stash[[:space:]]+(drop|clear)|rm[[:space:]])" \
  && decide ask "This git command discards or rewrites work (the tree may hold the user's uncommitted changes)."

# 3. Deleting and copying off the machine.
has "${S}rm[[:space:]]+(-[a-zA-Z]*[rRf]|--recursive|--force)" && decide ask "rm -r/-f deletes recursively or without a prompt."
has "${S}(scp|rsync)[[:space:]]" && decide ask "Copies files to or from another machine."

# 4. Outward-facing: releases, store uploads, live backends.
has "${S}(firebase|firebase-tools)[[:space:]]+([^|;&]*[[:space:]])?deploy" && decide ask "firebase deploy changes the live Firebase project."
has "${S}flutterfire[[:space:]]+configure" && decide ask "flutterfire configure rewrites Firebase config files for every platform."
has "${S}shorebird[[:space:]]+(release|patch)" && decide ask "Shorebird release/patch ships code to users' phones."
has "${S}(fastlane|bundle[[:space:]]+exec[[:space:]]+fastlane)[[:space:]]" && decide ask "fastlane lanes usually upload to the stores."
has "${S}gh[[:space:]]+release[[:space:]]+(create|upload|delete)" && decide ask "Creates or changes a public GitHub release."

# 5. Devices: wiping app data, and Patrol picking a physical phone.
has "${S}adb[[:space:]]+([^|;&]*[[:space:]])?(uninstall|shell[[:space:]]+(pm[[:space:]]+(clear|uninstall)|rm[[:space:]]))" \
  && decide ask "This adb command wipes app data or files on the device."
if has "${S}patrol[[:space:]]+(test|develop)([[:space:]]|$)" && ! has "(-d|--device)[[:space:]=]+emulator-[0-9]+"; then
  decide ask "patrol test/develop without -d emulator-N may pick a physical phone, and every run clears the app's data."
fi

# 6. Whole-tree formatting buries the real diff.
has "${S}dart[[:space:]]+format[[:space:]]+(\.|lib|test|[^[:space:]]*/)?([[:space:]]|$)" \
  && decide ask "dart format on a whole directory rewrites files the task did not touch. Format only the files you changed."

exit 0

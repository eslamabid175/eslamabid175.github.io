#!/usr/bin/env python3
"""Check that every .arb locale has the same keys and placeholders as the template.

Reads arb-dir and template-arb-file from l10n.yaml (defaults: lib/l10n,
app_en.arb). For every other *.arb in that folder it reports:
  - keys missing from the locale
  - keys the template does not have (stale translations)
  - placeholders used by the template message but missing from the translation

    python3 .claude/bin/check_arb_parity.py            # exit 1 on any problem
    python3 .claude/bin/check_arb_parity.py path/to/package

Standard library only.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def read_l10n_yaml(pkg: Path) -> tuple[Path, str]:
    arb_dir, template = "lib/l10n", "app_en.arb"
    cfg = pkg / "l10n.yaml"
    if cfg.exists():
        for line in cfg.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^\s*(arb-dir|template-arb-file)\s*:\s*['\"]?([^'\"#]+?)['\"]?\s*(#.*)?$", line)
            if m and m.group(1) == "arb-dir":
                arb_dir = m.group(2)
            elif m:
                template = m.group(2)
    return pkg / arb_dir, template


def messages(path: Path) -> dict[str, str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("@") and isinstance(v, str)}


def placeholders(path: Path) -> dict[str, set[str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    out: dict[str, set[str]] = {}
    for key, value in data.items():
        if key.startswith("@") or not isinstance(value, str):
            continue
        meta = data.get(f"@{key}", {})
        declared = set((meta.get("placeholders") or {}).keys()) if isinstance(meta, dict) else set()
        out[key] = declared or set(re.findall(r"\{(\w+)\}", value))
    return out


def main() -> int:
    pkg = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    arb_dir, template_name = read_l10n_yaml(pkg)
    template = arb_dir / template_name
    if not template.exists():
        print(f"no template arb at {template} (check l10n.yaml)")
        return 1
    base = messages(template)
    base_ph = placeholders(template)
    problems = 0
    others = sorted(p for p in arb_dir.glob("*.arb") if p.name != template_name)
    for arb in others:
        loc = messages(arb)
        missing = sorted(set(base) - set(loc))
        extra = sorted(set(loc) - set(base))
        bad_ph = []
        for key, names in base_ph.items():
            if key in loc:
                lost = [n for n in names if not re.search(r"\{" + re.escape(n) + r"[\s,}]", loc[key])]
                if lost:
                    bad_ph.append(f"{key}: {', '.join(lost)}")
        for label, items in (("missing key", missing), ("not in template", extra), ("placeholder missing", bad_ph)):
            for item in items:
                print(f"{arb.name}: {label}: {item}")
        problems += len(missing) + len(extra) + len(bad_ph)
    print(f"arb parity: {len(others)} locale(s) vs {template_name}, {len(base)} keys, {problems} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

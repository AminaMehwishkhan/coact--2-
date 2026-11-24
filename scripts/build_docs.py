"""Regenerate docs/ — the static copy of the dashboard that GitHub Pages serves.

docs/ is a build output, not a second source. It holds the page from web/ next
to the two artefacts it loads at runtime (the camera figure and the recorded
episode), because a static host has no /api/frame to call and no results/
directory to reach into.

    python scripts/build_docs.py
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"

FILES = [
    (ROOT / "web" / "index.html", DOCS / "index.html"),
    (ROOT / "results" / "agent_views.png", DOCS / "agent_views.png"),
    (ROOT / "results" / "coact_demo.mp4", DOCS / "coact_demo.mp4"),
]


def main() -> int:
    DOCS.mkdir(exist_ok=True)
    # Pages runs Jekyll by default, which ignores files it does not understand.
    (DOCS / ".nojekyll").touch()

    missing = [src for src, _ in FILES if not src.exists()]
    if missing:
        for src in missing:
            print(f"missing: {src.relative_to(ROOT)}", file=sys.stderr)
        print("\nRun the benchmark and the recorder first:\n"
              "  python -m coact.benchmark --trials 90 --sizing both "
              "--out results/benchmark.json\n"
              "  python scripts/record_demo.py --out results", file=sys.stderr)
        return 1

    for src, dst in FILES:
        shutil.copy2(src, dst)
        print(f"{src.relative_to(ROOT)} -> {dst.relative_to(ROOT)} "
              f"({dst.stat().st_size / 1024:.0f} KB)")

    print(f"\ndocs/ rebuilt. Commit it, then set Pages to deploy from "
          f"main /docs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

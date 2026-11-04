"""Read-only search of the explicitly approved Glass Clock documents."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Iterable, Optional

# This is deliberately a filename allowlist, not a directory allowlist.  Adding
# a document requires changing this list in code, so the chat app can never
# range across the rest of Aaron's files.
APPROVED_FILES = (
    "README.md",
    "PLAN.md",
    "PRD.md",
    "HANDOFF.md",
    "IDEAS.md",
    "DESIGN_SYSTEM.md",
    "SMOOTHNESS.md",
    "OVERNIGHT_PLAN.md",
)

STOP_WORDS = {
    "a", "about", "and", "are", "does", "for", "from", "glass", "how",
    "is", "me", "of", "on", "project", "say", "tell", "the", "to", "what",
    "with",
}


def keywords(query: str) -> list[str]:
    """Return a small, deduplicated list of meaningful terms."""
    words: list[str] = []
    for word in re.findall(r"[A-Za-z0-9][A-Za-z0-9_-]*", query.lower()):
        if len(word) > 2 and word not in STOP_WORDS and word not in words:
            words.append(word)
    return words


def approved_paths(project_root: Path) -> Iterable[Path]:
    """Yield only files named in APPROVED_FILES directly inside project_root."""
    root = project_root.expanduser().resolve()
    for name in APPROVED_FILES:
        candidate = root / name
        if candidate.is_file():
            yield candidate


def search_project(query: str, project_root: Optional[Path] = None, limit: int = 40) -> list[str]:
    """Search approved files only and return source-labelled matching lines."""
    project_root = project_root or Path(__file__).resolve().parent.parent
    terms = keywords(query)
    if not terms:
        return []

    results: list[str] = []
    for path in approved_paths(project_root):
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for number, line in enumerate(lines, start=1):
            if any(term in line.lower() for term in terms):
                results.append(f"{path.name}:{number}: {line.strip()}")
                if len(results) >= limit:
                    return results
    return results


if __name__ == "__main__":
    matches = search_project(" ".join(sys.argv[1:]))
    print("\n".join(matches) if matches else "No matching lines found in approved documents.")

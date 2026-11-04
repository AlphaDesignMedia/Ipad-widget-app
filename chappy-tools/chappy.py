#!/usr/bin/env python3
"""Launch Chappy's built-in macOS chat window without third-party packages."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def main() -> None:
    app_dir = Path(__file__).resolve().parent
    if sys.platform != "darwin":
        raise SystemExit("Chappy's native window is available on macOS only.")
    project_root = Path(os.environ.get("CHAPPY_PROJECT_ROOT", str(Path.cwd()))).expanduser().resolve()
    dashboard = project_root / "pip-sandbox-claude-code" / "index.html"
    environment = dict(
        os.environ,
        CHAPPY_APP_DIR=str(app_dir),
        CHAPPY_PROJECT_ROOT=str(project_root),
        CHAPPY_DASHBOARD_PATH=str(dashboard) if dashboard.is_file() else "",
    )
    subprocess.run(
        ["/usr/bin/osascript", "-l", "JavaScript", str(app_dir / "chappy_macos.js")],
        env=environment,
        check=False,
    )


if __name__ == "__main__":
    main()

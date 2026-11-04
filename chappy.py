#!/usr/bin/env python3
"""Compatibility launcher for Chappy's scoped app files."""

from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).resolve().parent / "chappy-tools" / "chappy.py"), run_name="__main__")

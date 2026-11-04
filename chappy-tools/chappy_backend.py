"""One-turn local Chappy backend, called only by the built-in macOS window."""

from __future__ import annotations

import base64
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

from search_project import search_project

OLLAMA_BASE = os.environ.get("CHAPPY_OLLAMA", "http://127.0.0.1:11434").rstrip("/")
MODEL = os.environ.get("CHAPPY_MODEL", "qwen2.5-coder:7b")
PROJECT_ROOT = Path(os.environ.get("CHAPPY_PROJECT_ROOT", str(Path.cwd()))).expanduser().resolve()
TOOL_REQUEST = re.compile(r"^\s*SEARCH_PROJECT\s*:\s*(.+?)\s*$", re.IGNORECASE | re.MULTILINE)

SYSTEM = """You are Chappy, a private local assistant for the Glass Clock project.
Be helpful, concise, and honest about uncertainty. Default to a short answer: at most six bullets or about 220 words.
For a question requiring the approved project documents,
respond with exactly one line: SEARCH_PROJECT: <focused search terms>. You may request one search per user message.
For project summaries, outstanding-task lists, or handover/report drafts, search the approved documents first when
they are relevant. Keep drafts clearly labelled as drafts and distinguish evidence, open questions, and suggestions.
You cannot edit files, access other locations, send messages, or take actions outside this chat."""

FINAL_SYSTEM = """You are Chappy, a private local assistant for the Glass Clock project.
The one permitted project search for this message is complete. Answer using the results where useful.
Default to at most six bullets or about 220 words. Do not request another search, do not output SEARCH_PROJECT,
and do not claim to have edited, sent, or accessed anything else."""


def ask(messages: list[dict[str, str]]) -> str:
    data = json.dumps({
        "model": MODEL,
        "messages": messages,
        "stream": False,
        "keep_alive": "10m",
        "options": {"num_predict": 300, "temperature": 0.2},
    }).encode("utf-8")
    request = urllib.request.Request(f"{OLLAMA_BASE}/api/chat", data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            reply = json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as error:
        raise RuntimeError("Ollama is unavailable. Start it, then try again.") from error
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError("Ollama returned an unreadable response.") from error
    text = reply.get("message", {}).get("content", "").strip()
    if not text:
        raise RuntimeError("Ollama returned an empty reply.")
    return text


def reply(prompt: str, history: list[dict[str, str]]) -> tuple[str, bool]:
    """Permit one project search and a maximum of two model calls."""
    history = history[-10:]
    first = ask([{"role": "system", "content": SYSTEM}, *history, {"role": "user", "content": prompt}])
    request = TOOL_REQUEST.match(first)
    if not request:
        return first, False
    query = request.group(1).strip()
    matches = search_project(query, PROJECT_ROOT, limit=12)
    found = "\n".join(matches) if matches else "No matching lines found in approved documents."
    final = ask([
        {"role": "system", "content": FINAL_SYSTEM}, *history,
        {"role": "user", "content": prompt},
        {"role": "assistant", "content": first},
        {"role": "user", "content": f"Search results for {query!r}:\n{found}"},
    ])
    if TOOL_REQUEST.match(final):
        final = "I searched the approved project documents once.\n\n" + found
    return final, True


def main() -> None:
    try:
        payload = json.loads(base64.b64decode(sys.argv[1]).decode("utf-8"))
        answer, searched = reply(str(payload["prompt"]), list(payload.get("history", [])))
        print(json.dumps({"reply": answer, "searched": searched}))
    except (IndexError, KeyError, ValueError, RuntimeError) as error:
        print(json.dumps({"error": str(error)}))


if __name__ == "__main__":
    main()

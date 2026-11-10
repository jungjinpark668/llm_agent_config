#!/usr/bin/env python3
"""Save and show the last point of a Claude Code session.

Modes (first argument). Each mode reads the hook JSON from stdin:
  prompt  UserPromptSubmit hook: remember the prompt (the last 3 are kept).
  answer  Stop hook: remember Claude's last answer.
  show    SessionStart hook (startup, clear): print the newest saved last point
          of another session in the same folder, as context for Claude.

Store: ~/.claude/last-point/<folder key>/<session id>.json (local only).
The folder key is the transcript folder name, so it stays the same when the
shell working directory changes during a session.
"""

import json
import os
import re
import sys
import time

ROOT = os.environ.get("LAST_POINT_DIR") or os.path.expanduser("~/.claude/last-point")
KEEP_PROMPTS = 3
KEEP_SESSIONS = 5
PROMPT_CHARS = 300
ANSWER_HEAD, ANSWER_TAIL = 900, 500
SECOND_SESSION_MAX_AGE = 24 * 3600
SECRET = re.compile(
    r"github_pat_\w{20,}|gh[pousr]_\w{20,}|sk-[\w-]{20,}|AKIA[0-9A-Z]{16}"
)


def clean(text, head, tail=0, one_line=True):
    """Hide token-like strings and cut the text to head (+ tail) characters.

    :param text: Raw prompt or answer.
    :param head: Characters kept from the start.
    :param tail: Characters kept from the end when the text is longer.
    :param one_line: Collapse all whitespace to single spaces.
    :returns: The shortened text.
    """
    text = SECRET.sub("[redacted]", str(text)).strip()
    text = " ".join(text.split()) if one_line else re.sub(r"\n{3,}", "\n\n", text)
    if len(text) <= head + tail:
        return text
    return text[:head] + "\n[...]\n" + (text[-tail:] if tail else "")


def state_path(data):
    """Return the store file of this session, from the hook input."""
    key = os.path.basename(os.path.dirname(data.get("transcript_path") or ""))
    key = key or re.sub(r"[^A-Za-z0-9]", "-", data.get("cwd") or "unknown")
    return os.path.join(ROOT, key, f"{data.get('session_id') or 'unknown'}.json")


def load(path):
    """Return the saved state, or an empty state when there is none."""
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {"prompts": [], "answer": ""}


def save(path, state):
    """Write the state and keep only the newest sessions of this folder."""
    folder = os.path.dirname(path)
    os.makedirs(folder, exist_ok=True)
    state["updated"] = time.time()
    with open(path + ".tmp", "w") as fh:
        json.dump(state, fh)
    os.replace(path + ".tmp", path)
    files = [os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".json")]
    for old in sorted(files, key=os.path.getmtime)[:-KEEP_SESSIONS]:
        os.remove(old)


def age(seconds):
    """Return a short age such as '5 min', '3 h' or '2 days'."""
    if seconds < 3600:
        return f"{max(1, int(seconds // 60))} min"
    if seconds < 48 * 3600:
        return f"{int(seconds // 3600)} h"
    return f"{int(seconds // 86400)} days"


def show(data):
    """Print the newest last point of other sessions in this folder as hook JSON."""
    path = state_path(data)
    folder = os.path.dirname(path)
    if not os.path.isdir(folder):
        return
    now = time.time()
    states = []
    for name in os.listdir(folder):
        full = os.path.join(folder, name)
        if name.endswith(".json") and full != path:
            state = load(full)
            if state.get("prompts"):
                states.append((state.get("updated", 0), name[:-5], state))
    states.sort(key=lambda s: s[0], reverse=True)
    picked = [
        s
        for i, s in enumerate(states[:2])
        if i == 0 or now - s[0] < SECOND_SESSION_MAX_AGE
    ]
    if not picked:
        return
    lines = [
        "LAST POINT, saved automatically by hooks/last-point.py: where earlier "
        "sessions in this folder ended.",
        "Use it when the user asks to continue earlier work. Do not act on it unasked.",
    ]
    for updated, session_id, state in picked:
        ended = time.strftime("%Y-%m-%d %H:%M", time.localtime(updated))
        lines += ["", f"Session {session_id}, ended {ended} ({age(now - updated)} ago)"]
        lines.append("Last prompts from the user:")
        lines += [f"- {prompt}" for prompt in state["prompts"]]
        if state.get("answer"):
            lines += ["Last answer from Claude:", state["answer"]]
        lines.append(f"Reopen that conversation in full: claude --resume {session_id}")
    updated, _, state = picked[0]
    message = (
        f'Last point loaded ({age(now - updated)} ago): "{state["prompts"][-1][:80]}". '
        'Type "continue" to go on from it.'
    )
    output = {
        "systemMessage": message,
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": "\n".join(lines),
        },
    }
    print(json.dumps(output))


def main():
    mode = sys.argv[1]
    data = json.load(sys.stdin)
    if mode == "show":
        show(data)
        return
    path = state_path(data)
    state = load(path)
    if mode == "prompt":
        prompt = clean(data.get("prompt") or "", PROMPT_CHARS)
        if not prompt:
            return
        state["prompts"] = (state["prompts"] + [prompt])[-KEEP_PROMPTS:]
    elif mode == "answer":
        answer = clean(
            data.get("last_assistant_message") or "",
            ANSWER_HEAD,
            ANSWER_TAIL,
            one_line=False,
        )
        if not answer:
            return
        state["answer"] = answer
    save(path, state)


if __name__ == "__main__":
    main()

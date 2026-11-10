#!/usr/bin/env python3
"""Save and show the last point of a Claude Code session.

Usage: last-point.py <mode> [<pid of the Claude Code process>]
Each mode reads the hook JSON from stdin:
  prompt  UserPromptSubmit hook: remember the prompt (the last 3 are kept).
  answer  Stop hook: remember Claude's last answer.
  show    SessionStart hook (startup, clear): print the saved last points of
          the other sessions in the same folder, as context for Claude.

Store: ~/.claude/last-point/<folder key>/<session id>.json (local only).
The folder key is the transcript folder name, so it stays the same when the
shell working directory changes during a session.

Several sessions at once: every session has its own file, so sessions never
overwrite each other. The hook command passes $PPID, the pid of the Claude
Code process that runs the session, and every save stores it. /clear keeps
that process and starts a new session id, so after /clear the file with the
same pid is the session that was just cleared: show puts it first. A file
whose pid is another running process is a session still open in another
terminal: show marks it.
"""

import json
import os
import re
import subprocess
import sys
import time

ROOT = os.environ.get("LAST_POINT_DIR") or os.path.expanduser("~/.claude/last-point")
KEEP_PROMPTS = 3
KEEP_SESSIONS = 10
SHOW_OTHERS = 5
PROMPT_CHARS = 300
ANSWER_HEAD, ANSWER_TAIL = 900, 500
CLEARED = "the session just cleared in this terminal"
OPEN = "STILL OPEN in another terminal"
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


def started(pid):
    """Return the start time of process pid in epoch seconds, or None if it is gone."""
    out = subprocess.run(
        ["ps", "-o", "etime=", "-p", str(pid)], capture_output=True, text=True
    ).stdout.strip()
    if not out:
        return None
    days, _, clock = out.rpartition("-")  # etime format: [[dd-]hh:]mm:ss
    seconds = 0
    for part in clock.split(":"):
        seconds = seconds * 60 + int(part)
    return time.time() - int(days or 0) * 86400 - seconds


def title(session_id, state, mark, now):
    """Return the heading of one session: id, save time and mark."""
    saved = time.strftime("%Y-%m-%d %H:%M", time.localtime(state["updated"]))
    text = (
        f"Session {session_id}, last saved {saved} ({age(now - state['updated'])} ago)"
    )
    return f"{text}, {mark}" if mark else text


def show(data, pid):
    """Print the last points of the other sessions in this folder as hook JSON.

    :param data: Hook input of the session that starts.
    :param pid: Pid of its Claude Code process, or None when unknown.
    """
    path = state_path(data)
    folder = os.path.dirname(path)
    if not os.path.isdir(folder):
        return
    states = []
    for name in os.listdir(folder):
        full = os.path.join(folder, name)
        if name.endswith(".json") and full != path:
            state = load(full)
            if state.get("prompts"):
                states.append((name[:-5], state))
    if not states:
        return
    states.sort(key=lambda s: s[1]["updated"], reverse=True)
    # The newest file of a running process is the session that process is on.
    # A process started after the save is another process that reuses the pid
    # (ps reports whole seconds, hence the 2 s margin).
    seen, sessions = set(), []
    for session_id, state in states:
        owner, mark = state.get("pid"), ""
        if owner and owner not in seen:
            seen.add(owner)
            start = started(owner)
            if start is not None and start - 2 <= state["updated"]:
                mark = CLEARED if owner == pid else OPEN
        sessions.append((session_id, state, mark))
    sessions.sort(key=lambda s: s[2] != CLEARED)  # stable sort: cleared session first
    now = time.time()
    session_id, state, mark = sessions[0]
    others = sessions[1 : 1 + SHOW_OTHERS]
    lines = [
        "LAST POINT, saved automatically by hooks/last-point.py. Every session of "
        "this folder saves its own last point.",
        "Use it when the user asks to continue earlier work. Do not act on it unasked.",
    ]
    if others:
        lines.append(
            "If several sessions below could be meant, ask the user which one."
        )
    if any(s[2] == OPEN for s in sessions[: 1 + SHOW_OTHERS]):
        lines.append(
            f"A session marked {OPEN} is running right now. Continue its work here "
            "only after the user confirms: two sessions on one task can edit the "
            "same files."
        )
    lines += ["", title(session_id, state, mark, now), "Last prompts from the user:"]
    lines += [f"- {prompt}" for prompt in state["prompts"]]
    if state.get("answer"):
        lines += ["Last answer from Claude:", state["answer"]]
    lines.append(f"Reopen that conversation in full: claude --resume {session_id}")
    if others:
        lines += [
            "",
            "Other sessions of this folder, newest first (full last point of each: "
            f"{folder}/<session id>.json):",
        ]
        lines += [
            f"- {title(*other, now)}. Last prompt: {other[1]['prompts'][-1][:150]}"
            for other in others
        ]
    message = (
        f"Last point loaded ({age(now - state['updated'])} ago"
        f'{", " + mark if mark else ""}): "{state["prompts"][-1][:80]}". '
        'Type "continue" to go on from it.'
    )
    if others:
        message += f" Other sessions of this folder listed: {len(others)}."
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
    pid = int(sys.argv[2]) if len(sys.argv) > 2 else None
    data = json.load(sys.stdin)
    if mode == "show":
        show(data, pid)
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
    if pid:
        state["pid"] = pid
    save(path, state)


if __name__ == "__main__":
    main()

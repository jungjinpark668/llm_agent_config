"""Unit tests for hooks/last-point.py. Usage: python3 hooks/tests/test_last_point.py"""

import json
import os
import subprocess
import sys
import tempfile
import time

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "last-point.py")
PROCS = []


def run(mode, payload, store, pid=None):
    args = ["python3", SCRIPT, mode] + ([str(pid)] if pid else [])
    out = subprocess.run(
        args,
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env={**os.environ, "LAST_POINT_DIR": store},
    )
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout) if out.stdout.strip() else None


def ev(session, folder="-fake-folder", **more):
    path = f"/x/projects/{folder}/{session}.jsonl"
    return {"session_id": session, "transcript_path": path, "cwd": "/fake", **more}


def proc():
    """A live process that stands in for one Claude Code process (one terminal)."""
    p = subprocess.Popen(["sleep", "300"])
    PROCS.append(p)
    return p


def say(store, session, pid, prompt, answer=None, folder="-fake-folder"):
    run("prompt", ev(session, folder, prompt=prompt), store, pid)
    if answer:
        run("answer", ev(session, folder, last_assistant_message=answer), store, pid)


def ctx(out):
    return out["hookSpecificOutput"]["additionalContext"]


def state(store, session, folder="-fake-folder"):
    return json.load(open(os.path.join(store, folder, session + ".json")))


def test_folders_do_not_mix():
    store = tempfile.mkdtemp()
    say(store, "A", None, "work in folder one", folder="-one")
    assert run("show", ev("B", "-two", source="startup"), store) is None
    out = run("show", ev("B", "-one", source="startup"), store)
    assert "work in folder one" in ctx(out)


def test_sessions_have_own_files():
    store = tempfile.mkdtemp()
    for i in range(3):
        say(store, "S1", None, f"one-{i}")
        say(store, "S2", None, f"two-{i}")
    assert state(store, "S1")["prompts"] == ["one-0", "one-1", "one-2"]
    assert state(store, "S2")["prompts"] == ["two-0", "two-1", "two-2"]


def test_clear_shows_the_cleared_session_first():
    store = tempfile.mkdtemp()
    p1, p2, p3 = proc(), proc(), proc()
    say(store, "S1", p1.pid, "terminal 1: fix the LMS loop", "S1 answer")
    say(store, "S2", p2.pid, "terminal 2: plot the BER curve")
    say(store, "S3", p3.pid, "terminal 3: write the report")
    out = run("show", ev("S1b", source="clear"), store, p1.pid)
    text = ctx(out)
    first = text.split("Other sessions of this folder")[0]
    rest = text.split("Other sessions of this folder")[1]
    assert (
        "Session S1, last saved" in first and "just cleared in this terminal" in first
    )
    assert "terminal 1: fix the LMS loop" in first and "S1 answer" in first
    assert "S2" not in first and "S3" not in first
    assert rest.index("Session S3") < rest.index("Session S2")
    assert rest.count("STILL OPEN in another terminal") == 2
    assert "ask the user which one" in text and "only after the user confirms" in text
    msg = out["systemMessage"]
    assert "terminal 1: fix the LMS loop" in msg and "just cleared" in msg
    assert "listed: 2" in msg
    assert out["hookSpecificOutput"]["hookEventName"] == "SessionStart"
    return store, (p1, p2, p3)


def test_startup_marks_open_sessions():
    store, (p1, p2, p3) = test_clear_shows_the_cleared_session_first()
    p4 = proc()
    out = run("show", ev("S4", source="startup"), store, p4.pid)
    text = ctx(out)
    first = text.split("Other sessions of this folder")[0]
    assert (
        "Session S3, last saved" in first and "STILL OPEN in another terminal" in first
    )
    assert "just cleared" not in text
    assert text.count("STILL OPEN in another terminal") == 4  # 1 rule line + 3 sessions
    # terminal 2 closes: its session loses the mark
    p2.kill()
    p2.wait()
    text = ctx(run("show", ev("S4", source="startup"), store, p4.pid))
    line = [row for row in text.splitlines() if row.startswith("- Session S2")][0]
    assert "STILL OPEN" not in line
    assert text.count("STILL OPEN in another terminal") == 3


def test_pid_reuse_is_not_open():
    store = tempfile.mkdtemp()
    p = proc()
    say(store, "OLD", p.pid, "old work")
    path = os.path.join(store, "-fake-folder", "OLD.json")
    data = json.load(open(path))
    data["updated"] = time.time() - 1000  # saved before process p started
    json.dump(data, open(path, "w"))
    out = run("show", ev("NEW", source="startup"), store, proc().pid)
    assert "STILL OPEN" not in ctx(out) and "just cleared" not in ctx(out)
    # same pid as the starting process, but the process is younger than the save
    out = run("show", ev("NEW", source="clear"), store, p.pid)
    assert "just cleared" not in ctx(out) and "STILL OPEN" not in ctx(out)


def test_only_newest_file_of_a_process_is_marked():
    store = tempfile.mkdtemp()
    p1 = proc()
    say(store, "EARLIER", p1.pid, "earlier session of terminal 1")
    say(store, "LATER", p1.pid, "later session of terminal 1")
    text = ctx(run("show", ev("NEW", source="clear"), store, p1.pid))
    assert text.count("just cleared in this terminal") == 1
    first = text.split("Other sessions of this folder")[0]
    assert "Session LATER" in first


def test_no_pid_argument_and_old_files():
    store = tempfile.mkdtemp()
    say(store, "S1", None, "saved by the old command", "answer one")
    assert "pid" not in state(store, "S1")
    out = run("show", ev("S2", source="startup"), store)
    assert "saved by the old command" in ctx(out)
    assert "STILL OPEN" not in ctx(out) and "just cleared" not in ctx(out)
    assert "ask the user which one" not in ctx(out)  # one session only
    assert "listed" not in out["systemMessage"]
    out = run("show", ev("S2", source="startup"), store, proc().pid)
    assert "STILL OPEN" not in ctx(out)


def test_keep_and_list_limits():
    store = tempfile.mkdtemp()
    for i in range(12):
        say(store, f"S{i:02d}", None, f"prompt {i}")
        time.sleep(0.02)
    files = sorted(os.listdir(os.path.join(store, "-fake-folder")))
    assert files == [f"S{i:02d}.json" for i in range(2, 12)], files
    text = ctx(run("show", ev("NEW", source="startup"), store))
    assert text.count("last saved") == 6  # 1 in full + 5 others
    assert "Session S11, last saved" in text.split("Other sessions")[0]


def test_own_file_is_not_shown():
    store = tempfile.mkdtemp()
    say(store, "S1", None, "my own prompt")
    assert run("show", ev("S1", source="clear"), store) is None


def test_trimming_and_redaction():
    store = tempfile.mkdtemp()
    fake = "ghp_" + "a" * 30
    for i in range(5):
        say(store, "S1", None, f"p{i} " + "x" * 400 + fake)
    s = state(store, "S1")
    assert len(s["prompts"]) == 3 and s["prompts"][0].startswith("p2 ")
    assert all(len(p) < 320 for p in s["prompts"])
    run(
        "answer",
        ev("S1", last_assistant_message="H" * 1000 + " " + fake + " " + "T" * 1000),
        store,
    )
    answer = state(store, "S1")["answer"]
    assert (
        fake not in answer
        and answer.startswith("H" * 900)
        and answer.endswith("T" * 500)
    )
    run("answer", ev("S1", last_assistant_message=""), store)
    assert state(store, "S1")["answer"] == answer  # an empty answer never overwrites
    run("prompt", ev("S1", prompt="token " + fake), store)
    assert fake not in json.dumps(state(store, "S1"))


if __name__ == "__main__":
    failed = 0
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn()
                print("PASS", name)
            except AssertionError as err:
                failed += 1
                print("FAIL", name, err)
    for p in PROCS:
        p.kill()
    sys.exit(1 if failed else 0)

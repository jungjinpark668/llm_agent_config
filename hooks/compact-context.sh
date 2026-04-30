#!/bin/bash
# Re-inject key project reminders after context compaction.
# Runs on SessionStart with matcher "compact".
cat << 'EOF'
REMINDER after compaction:
- Separation of concerns: classes don't call other classes. Orchestration in scripts/tests.
- Prefer extending existing methods with optional params over new methods.
- No auto-commit. User must request commits explicitly.
- phi=azimuth, theta=elevation convention.
- Package: psylab-comm — digital communication research toolkit.
EOF
exit 0

#!/bin/bash
# Portable advisory lock for hooks. macOS has no flock, so we use mkdir,
# which is atomic across processes on every filesystem the vault lives on.
#
# Usage:
#   source "$SCRIPT_DIR/lib/locking.sh"
#   if acquire_lock "$LOCKDIR" 3; then
#       # critical section
#       release_lock "$LOCKDIR"
#   fi
#
# acquire_lock <lockdir> [max_wait_secs]
#   Returns 0 once held. Waits up to max_wait_secs (default 3, 0 = non-blocking).
#   A lock older than 30s is treated as stale (holder died) and stolen.
#   Returns 1 if the wait elapsed without acquiring — caller decides what to do.
acquire_lock() {
    local lockdir="$1"
    local max_wait="${2:-3}"
    local iters=0
    local limit=$(( max_wait * 5 ))   # one iteration = 0.2s
    while ! mkdir "$lockdir" 2>/dev/null; do
        local now mtime
        now=$(date +%s)
        mtime=$(stat -f %m "$lockdir" 2>/dev/null || stat -c %Y "$lockdir" 2>/dev/null || echo "$now")
        if [ $(( now - mtime )) -gt 30 ]; then
            rm -rf "$lockdir" 2>/dev/null
            continue
        fi
        if [ "$iters" -ge "$limit" ]; then
            return 1
        fi
        sleep 0.2
        iters=$(( iters + 1 ))
    done
    return 0
}

# release_lock <lockdir>
release_lock() {
    rm -rf "$1" 2>/dev/null || true
}

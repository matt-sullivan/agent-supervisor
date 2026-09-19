#!/usr/bin/env bash
# Ensures claude --remote-control is running on this host.
set -euo pipefail

case "$(hostname)" in
    deploy-srv) session_name="Deploy-srv Agent Supervisor" ;;
    agent-srv)  session_name="Master Agent Supervisor" ;;
    *)
        echo "error: no supervisor session name configured for host '$(hostname)'" >&2
        exit 1
        ;;
esac

if pgrep -x claude >/dev/null; then
    exit 0
fi

tmux_session="agent-supervisor"
work_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmux has-session -t "$tmux_session" 2>/dev/null || tmux new-session -d -s "$tmux_session" -c "$work_dir"

tmux send-keys -t "$tmux_session" \
    "claude --resume \"$session_name\" --remote-control \"$session_name\" || claude -n \"$session_name\" --remote-control \"$session_name\"" \
    Enter

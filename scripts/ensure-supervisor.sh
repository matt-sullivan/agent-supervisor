#!/usr/bin/env bash
# Ensures this VM's outer supervisor session is running: a tmux session (survives SSH disconnects and
# reboots) with one `claude --remote-control` process inside it, reachable from claude.ai/code or the
# Claude app. This is the "one outer claude session running directly on the host, outside any
# devcontainer" from vm-configs/README.md's dev-environment model, applied to the supervisor itself -
# each VM always resumes the same named session so its history persists across restarts of this script.
# Idempotent - safe to run repeatedly (e.g. from cron or a boot-time systemd unit).
set -euo pipefail

case "$(hostname)" in
    deploy-srv) session_name="Deploy-srv Agent Supervisor" ;;
    agent-srv)  session_name="Master Agent Supervisor" ;;
    *)
        echo "error: no supervisor session name configured for host '$(hostname)'" >&2
        exit 1
        ;;
esac

tmux_session="agent-supervisor"
work_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! tmux has-session -t "$tmux_session" 2>/dev/null; then
    tmux new-session -d -s "$tmux_session" -c "$work_dir"
fi

running_cmd="$(tmux list-panes -t "$tmux_session" -F '#{pane_current_command}' | head -1)"
if [ "$running_cmd" = "claude" ]; then
    echo "Already running: tmux attach -t $tmux_session"
    exit 0
fi

# Falls back to a fresh session under the same name if there's no local history to resume (e.g. first
# run ever on this VM). Confirmed working across a full OS rebuild of deploy-srv: $HOME lives on the
# persistent data disk on these VMs (see vm-configs AGENTS.md's agent-srv/deploy-srv pattern notes),
# not the OS disk that gets recreated, so ~/.claude/projects survives and --resume finds it - a rebuilt
# VM does not mean lost session history here, even though the VM itself is "cattle not pets."
tmux send-keys -t "$tmux_session" \
    "claude --resume \"$session_name\" --remote-control \"$session_name\" || claude -n \"$session_name\" --remote-control \"$session_name\"" \
    Enter

echo "Launched '$session_name' in tmux session '$tmux_session'. Attach: tmux attach -t $tmux_session"

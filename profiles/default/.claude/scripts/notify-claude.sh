#!/usr/bin/env bash
# OS-dependent notification for Claude Code completion
# Part of dotfiles configuration - stows to ~/.claude/scripts/notify-claude.sh

set -euo pipefail

# Detect OS and send appropriate notification
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS notification with sound
    osascript -e 'display notification "Claude complete" sound name "Glass"'
elif [[ "$(uname)" == "Linux" ]]; then
    # Linux notification (Ubuntu, Debian, etc.)
    notify-send "Claude complete" --urgency=normal

    # Optional: Uncomment to add sound on Linux
    # Requires pulseaudio-utils package
    # paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
fi

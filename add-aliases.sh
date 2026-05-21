#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_CHAT_SCRIPT="$SCRIPT_DIR/ai-chat.sh"

CURRENT_SHELL=$(basename "$SHELL")
if [ "$CURRENT_SHELL" = "zsh" ]; then
    RC_FILE="$HOME/.zshrc"
elif [ "$CURRENT_SHELL" = "bash" ]; then
    RC_FILE="$HOME/.bashrc"
else
    echo "Unsupported shell: $CURRENT_SHELL (only bash/zsh)" >&2
    exit 1
fi

if [ ! -f "$RC_FILE" ]; then
    echo "Creating $RC_FILE ..."
    touch "$RC_FILE"
fi

ADDED_ANY=0

# Add chat alias if missing
if ! grep -Fq "alias \\?=" "$RC_FILE"; then
    {
        echo "";
        echo "# Reka AI Chat Alias";
        echo "alias \\?=\"$AI_CHAT_SCRIPT\"";
    } >> "$RC_FILE"
    echo "✓ Added chat alias '?'"
    ADDED_ANY=1
fi


if [ $ADDED_ANY -eq 0 ]; then
    echo "No changes: aliases already present in $RC_FILE"
else
    echo "Reload shell config with: source $RC_FILE"
fi

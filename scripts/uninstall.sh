#!/usr/bin/env bash
set -euo pipefail

echo "Claude Code Statusbar: Uninstalling..."
echo ""

CLAUDE_DIR="${HOME}/.claude"
DEST_FILE="${CLAUDE_DIR}/statusline-command.sh"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
BACKUP_DIR="${CLAUDE_DIR}/.statusbar-backup"

# --- Restore or remove statusline script ---
if [ -f "${BACKUP_DIR}/statusline-command.sh" ]; then
    cp "${BACKUP_DIR}/statusline-command.sh" "$DEST_FILE"
    echo "Restored: Previous statusline script from backup."
elif [ -f "$DEST_FILE" ]; then
    rm "$DEST_FILE"
    echo "Removed: ${DEST_FILE}"
else
    echo "Script not found — skipping."
fi

# --- Restore or remove statusLine from settings ---
if [ -f "${BACKUP_DIR}/statusline-settings.json" ]; then
    BACKUP_CONFIG=$(jq -c '.statusLine' "${BACKUP_DIR}/statusline-settings.json")
    if [ -f "$SETTINGS_FILE" ]; then
        jq --argjson sl "$BACKUP_CONFIG" '.statusLine = $sl' "$SETTINGS_FILE" > /tmp/cs.json && mv /tmp/cs.json "$SETTINGS_FILE"
        echo "Restored: Previous statusLine config in settings.json."
    fi
elif [ -f "$SETTINGS_FILE" ] && jq -e '.statusLine' "$SETTINGS_FILE" > /dev/null 2>&1; then
    jq 'del(.statusLine)' "$SETTINGS_FILE" > /tmp/cs.json && mv /tmp/cs.json "$SETTINGS_FILE"
    echo "Removed: statusLine from settings.json."
else
    echo "Settings: No statusLine found — skipping."
fi

# --- Clean up backup directory ---
if [ -d "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
    echo "Cleaned up: Backup directory removed."
fi

echo ""
echo "Uninstalled. Restart Claude Code to apply changes."

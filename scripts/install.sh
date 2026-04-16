#!/usr/bin/env bash
set -euo pipefail

echo "Claude Code Statusbar: Installing..."
echo ""

# --- Check dependencies ---
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "  macOS:  brew install jq"
    echo "  Linux:  sudo apt install jq"
    exit 1
fi

# --- Determine install location ---
CLAUDE_DIR="${HOME}/.claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${SCRIPT_DIR}/statusbar.sh"
DEST_FILE="${CLAUDE_DIR}/statusbar-command.sh"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

if [ ! -d "$CLAUDE_DIR" ]; then
    echo "Error: ~/.claude directory not found. Is Claude Code installed?"
    exit 1
fi

if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: statusbar.sh not found at ${SOURCE_FILE}"
    exit 1
fi

# --- Backup existing statusbar if present ---
BACKUP_DIR="${CLAUDE_DIR}/.statusbar-backup"
if [ -f "$DEST_FILE" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$DEST_FILE" "${BACKUP_DIR}/statusbar-command.sh"
    echo "Backup: Saved existing script to ${BACKUP_DIR}/statusbar-command.sh"
fi

if [ -f "$SETTINGS_FILE" ] && jq -e '.statusLine' "$SETTINGS_FILE" > /dev/null 2>&1; then
    mkdir -p "$BACKUP_DIR"
    jq '{statusLine: .statusLine}' "$SETTINGS_FILE" > "${BACKUP_DIR}/statusbar-settings.json"
    echo "Backup: Saved existing statusLine config to ${BACKUP_DIR}/statusbar-settings.json"
fi

# --- Install statusbar script ---
cp "$SOURCE_FILE" "$DEST_FILE"
chmod +x "$DEST_FILE"
echo "Installed: ${DEST_FILE}"

# --- Update settings.json ---
STATUSLINE_CONFIG='{"type":"command","command":"bash ~/.claude/statusbar-command.sh"}'

if [ -f "$SETTINGS_FILE" ]; then
    EXISTING=$(cat "$SETTINGS_FILE")

    # Check if statusLine is already configured
    if echo "$EXISTING" | jq -e '.statusLine' > /dev/null 2>&1; then
        CURRENT=$(echo "$EXISTING" | jq -c '.statusLine')
        if [ "$CURRENT" = "$STATUSLINE_CONFIG" ]; then
            echo "Settings: statusLine already configured — skipping."
        else
            echo "$EXISTING" | jq --argjson sl "$STATUSLINE_CONFIG" '.statusLine = $sl' > "$SETTINGS_FILE"
            echo "Settings: Updated statusLine in ${SETTINGS_FILE}"
        fi
    else
        echo "$EXISTING" | jq --argjson sl "$STATUSLINE_CONFIG" '. + {statusLine: $sl}' > "$SETTINGS_FILE"
        echo "Settings: Added statusLine to ${SETTINGS_FILE}"
    fi
else
    echo "{\"statusLine\":${STATUSLINE_CONFIG}}" | jq '.' > "$SETTINGS_FILE"
    echo "Settings: Created ${SETTINGS_FILE}"
fi

# --- Warn about disableAllHooks ---
if [ -f "$SETTINGS_FILE" ] && jq -e '.disableAllHooks == true' "$SETTINGS_FILE" > /dev/null 2>&1; then
    echo ""
    echo "Warning: disableAllHooks is set to true in your settings."
    echo "  The statusbar will NOT display until you set it to false:"
    echo "  jq '.disableAllHooks = false' ~/.claude/settings.json > /tmp/cs.json && mv /tmp/cs.json ~/.claude/settings.json"
fi

echo ""
echo "Claude Code Statusbar installed successfully."
echo ""
echo "Restart Claude Code to see your statusbar:"
echo ""
echo "  Opus 4.6  5hr:██░░░░░░░░ 12%  ctx:██░░░░░░░░ 24%  Code/myproject  main"
echo ""
echo "  - Model name (cyan)"
echo "  - 5hr rate limit (magenta → yellow → red)"
echo "  - Context window (blue → yellow → red)"
echo "  - Directory relative to ~"
echo "  - Git branch (green)"

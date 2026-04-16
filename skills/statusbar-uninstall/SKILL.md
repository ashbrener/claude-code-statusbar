---
name: statusbar-uninstall
description: Remove the Claude Code status bar and restore any previous statusline configuration
---

# Status Bar: Uninstall

Remove the Claude Code status bar and restore the user's previous configuration if one was backed up.

## Step 1: Check for backup

Look for `~/.claude/.statusbar-backup/` directory:
- `statusline-command.sh` — the previous statusline script
- `statusline-settings.json` — the previous statusLine config from settings.json

## Step 2: Restore or remove

### If backup exists:
- Copy `~/.claude/.statusbar-backup/statusline-command.sh` back to `~/.claude/statusline-command.sh`
- Read the backed-up `statusLine` value from `statusline-settings.json` and write it back into `~/.claude/settings.json`
- Tell the user their previous status bar has been restored

### If no backup:
- Delete `~/.claude/statusline-command.sh`
- Remove the `statusLine` key from `~/.claude/settings.json` (preserve all other settings)
- Tell the user the status bar has been removed

## Step 3: Clean up

- Delete `~/.claude/statusline-config.json` if it exists
- Delete `~/.claude/.statusbar-backup/` directory if it exists

## Step 4: Done

Tell the user to restart Claude Code to apply changes.

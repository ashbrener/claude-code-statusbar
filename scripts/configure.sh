#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.claude/statusline-config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="${SCRIPT_DIR}/defaults.json"

echo "Claude Code Statusbar — Configuration"
echo ""

# --- Load current or default config ---
if [ -f "$CONFIG_FILE" ]; then
    config=$(cat "$CONFIG_FILE")
    echo "Current config: ${CONFIG_FILE}"
else
    config=$(cat "$DEFAULT_CONFIG")
    echo "No config found — starting from defaults."
fi
echo ""

# --- Segment selection ---
echo "Which segments do you want? (comma-separated, or press Enter for default)"
echo "  Available: model, rate, context, directory, branch"
CURRENT_SEGS=$(echo "$config" | jq -r '.segments // ["model","rate","context","directory","branch"] | join(", ")')
echo "  Current:   ${CURRENT_SEGS}"
echo ""
read -rp "> " seg_input

if [ -n "$seg_input" ]; then
    # Parse comma-separated input into JSON array
    segs_json=$(echo "$seg_input" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | jq -R . | jq -s .)
    config=$(echo "$config" | jq --argjson s "$segs_json" '.segments = $s')
fi

# --- Segment order ---
echo ""
FINAL_SEGS=$(echo "$config" | jq -r '.segments | join(", ")')
echo "Segment order: ${FINAL_SEGS}"
echo "Reorder? (comma-separated, or press Enter to keep)"
read -rp "> " order_input

if [ -n "$order_input" ]; then
    order_json=$(echo "$order_input" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | jq -R . | jq -s .)
    config=$(echo "$config" | jq --argjson s "$order_json" '.segments = $s')
fi

# --- Bar style ---
echo ""
echo "Bar style:"
echo "  1) ██░░░░░░░░ (default)"
echo "  2) ■■□□□□□□□□"
echo "  3) ●●○○○○○○○○"
echo "  4) ##--------"
echo "  5) Custom"
read -rp "> " bar_choice

case "$bar_choice" in
    2) config=$(echo "$config" | jq '.bar.filled = "■" | .bar.empty = "□"') ;;
    3) config=$(echo "$config" | jq '.bar.filled = "●" | .bar.empty = "○"') ;;
    4) config=$(echo "$config" | jq '.bar.filled = "#" | .bar.empty = "-"') ;;
    5)
        read -rp "Filled character: " custom_fill
        read -rp "Empty character: " custom_empty
        config=$(echo "$config" | jq --arg f "$custom_fill" --arg e "$custom_empty" '.bar.filled = $f | .bar.empty = $e')
        ;;
esac

# --- Bar width ---
echo ""
CURRENT_WIDTH=$(echo "$config" | jq -r '.bar.width // 10')
echo "Bar width (current: ${CURRENT_WIDTH}, press Enter to keep):"
read -rp "> " width_input

if [ -n "$width_input" ]; then
    config=$(echo "$config" | jq --argjson w "$width_input" '.bar.width = $w')
fi

# --- Directory display ---
echo ""
echo "Directory relative to:"
echo "  1) home (~/)  (default)"
echo "  2) Full absolute path"
echo "  3) Custom prefix to strip"
read -rp "> " dir_choice

case "$dir_choice" in
    2) config=$(echo "$config" | jq '.directory.relative_to = "none"') ;;
    3)
        read -rp "Prefix to strip (e.g. /Users/me/Code/): " custom_prefix
        config=$(echo "$config" | jq --arg p "$custom_prefix" '.directory.relative_to = $p')
        ;;
esac

# --- Thresholds ---
echo ""
CURRENT_WARN=$(echo "$config" | jq -r '.thresholds.warning // 50')
CURRENT_CRIT=$(echo "$config" | jq -r '.thresholds.critical // 80')
echo "Color thresholds (when bars turn yellow/red):"
echo "  Warning at ${CURRENT_WARN}%, Critical at ${CURRENT_CRIT}%"
echo "  Press Enter to keep, or enter two numbers (e.g. 60 90):"
read -rp "> " thresh_input

if [ -n "$thresh_input" ]; then
    warn=$(echo "$thresh_input" | awk '{print $1}')
    crit=$(echo "$thresh_input" | awk '{print $2}')
    [ -n "$warn" ] && config=$(echo "$config" | jq --argjson w "$warn" '.thresholds.warning = $w')
    [ -n "$crit" ] && config=$(echo "$config" | jq --argjson c "$crit" '.thresholds.critical = $c')
fi

# --- Save ---
echo "$config" | jq '.' > "$CONFIG_FILE"
echo ""
echo "Saved: ${CONFIG_FILE}"
echo ""
echo "Preview (approximate):"
FILL=$(echo "$config" | jq -r '.bar.filled // "█"')
EMPTY=$(echo "$config" | jq -r '.bar.empty // "░"')
echo "  Opus 4.6  5hr:${FILL}${FILL}${EMPTY}${EMPTY}${EMPTY}${EMPTY}${EMPTY}${EMPTY}${EMPTY}${EMPTY} 20%  ctx:${FILL}${FILL}${FILL}${EMPTY}${EMPTY}${EMPTY}${EMPTY}${EMPTY}${EMPTY}${EMPTY} 30%  Code/myproject  main"
echo ""
echo "Restart Claude Code to apply."

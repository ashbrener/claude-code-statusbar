#!/usr/bin/env bash
# Claude Code Statusbar — https://github.com/ashbrener/claude-code-statusbar
#
# Displays a configurable statusbar with model, rate limits, context, prompt cache, directory, and git branch.
# Colors shift based on usage thresholds.
#
# Receives JSON on stdin from Claude Code's statusLine command runner.
# Configuration: ~/.claude/statusbar-config.json (falls back to built-in defaults)

input=$(cat)

# Every field below is a jq lookup against stdin. If stdin isn't valid JSON,
# each lookup fails independently and the bar renders half-built (e.g. a bare
# "●" with no model). Degrade to an empty object so defaults apply cleanly.
echo "$input" | jq -e . >/dev/null 2>&1 || input='{}'

# --- Load config ---
USER_CONFIG="${HOME}/.claude/statusbar-config.json"
if [ -f "$USER_CONFIG" ]; then
  config=$(cat "$USER_CONFIG")
  # Same hazard, worse blast radius: a malformed config makes the `.segments`
  # lookup fail, which empties the render loop and blanks the whole statusbar
  # with no visible cause. Fall back to built-in defaults instead.
  echo "$config" | jq -e . >/dev/null 2>&1 || config='{}'
else
  config='{}'
fi

cfg() { echo "$config" | jq -r "$1 // \"$2\""; }

# --- Parse input ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
used_ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
model_id=$(echo "$input" | jq -r '.model.id // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Rate limit — pick the window to display.
# `rate.window` config: a literal key (five_hour, seven_day, …) or "auto".
# Auto prefers the shortest-horizon window, since that's the one that will
# throttle you first; falls back to whatever key exists.
rate_window=$(echo "$config" | jq -r '.rate.window // "auto"')
if [ "$rate_window" = "auto" ]; then
  rate_key=$(echo "$input" | jq -r '
    (.rate_limits // {}) as $r
    | ["one_hour","five_hour","daily","seven_day"]
    | map(select(. as $k | $r | has($k)))
    | .[0] // ($r | keys[0]) // empty')
else
  rate_key=$(echo "$input" | jq -r --arg w "$rate_window" \
    '.rate_limits // {} | if has($w) then $w else (keys[0] // empty) end')
fi
rate_pct=""
rate_resets=""
rate_label="rate"
if [ -n "$rate_key" ]; then
  rate_pct=$(echo "$input" | jq -r ".rate_limits.${rate_key}.used_percentage // empty")
  rate_resets=$(echo "$input" | jq -r ".rate_limits.${rate_key}.resets_at // empty")
  case "$rate_key" in
    five_hour)  rate_label="5hr" ;;
    one_hour)   rate_label="1hr" ;;
    daily)      rate_label="day" ;;
    seven_day)  rate_label="7d" ;;
    *)          rate_label="$rate_key" ;;
  esac
fi

# Context gauge — measure against the auto-compact window, not the model's
# full window. `used_percentage` is a share of the full window, so with a 1M
# model and compaction set to 250k the gauge would read 25% at the moment the
# conversation is compacted and never reach its warning colours.
# `context.compact_at`: "auto" (read Claude Code's own setting), a token count,
# or "off" to keep measuring against the full window.
compact_at=$(echo "$config" | jq -r '.context.compact_at // "auto"')
if [ "$compact_at" = "auto" ]; then
  compact_at="${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}"
  claude_settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  if [ -z "$compact_at" ] && [ -f "$claude_settings" ]; then
    # A per-model window saved by /autocompact wins over the top-level key.
    compact_at=$(jq -r --arg m "$model_id" \
      '.modelSettings[$m].autoCompactWindow // .autoCompactWindow // empty' \
      "$claude_settings" 2>/dev/null)
  fi
fi
ctx_of_compact=""
case "$compact_at" in
  ''|*[!0-9]*|0) ;;
  *)
    case "$ctx_tokens" in
      ''|*[!0-9]*) ;;
      *)
        # Claude Code caps the window at the model's context window.
        case "$ctx_size" in
          ''|*[!0-9]*) ;;
          *) [ "$compact_at" -gt "$ctx_size" ] && compact_at="$ctx_size" ;;
        esac
        used_ctx=$(( ctx_tokens * 100 / compact_at ))
        [ "$used_ctx" -gt 100 ] && used_ctx=100
        ctx_of_compact=1
        ;;
    esac
    ;;
esac

# Weekly window — a second, compact rate gauge. The `rate` segment shows the
# window that throttles you first, which hides the seven-day limit until it is
# already spent. Skipped when `rate` is itself showing the seven-day window.
week_pct=""
week_resets=""
if [ "$rate_key" != "seven_day" ]; then
  week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
fi

# Prompt cache — one lookup for the whole object (Claude Code 2.1.251+).
# Absent before the first API response, and on providers that don't report
# cache tokens, in which case caching_observed stays false.
cache_observed="" cache_warm="" cache_expires="" cache_recache="" cache_misses=""
IFS='|' read -r cache_observed cache_warm cache_expires cache_recache cache_misses <<EOF_CACHE
$(echo "$input" | jq -r '.prompt_cache // {} | [
    (.caching_observed // false), (.warm // false), (.expires_at // ""),
    (.recache_tokens_if_cold // ""), (.misses // 0)
  ] | map(tostring) | join("|")')
EOF_CACHE

# --- Config values ---
SEGMENTS=$(echo "$config" | jq -r '.segments // ["model","thinking_stars","rate","weekly","context","cache","directory","branch"] | .[]')
C_MODEL=$(cfg '.colors.model' '96')
C_RATE=$(cfg '.colors.rate' '95')
C_CTX=$(cfg '.colors.context' '94')
C_CACHE=$(cfg '.colors.cache' '36')
C_DIR=$(cfg '.colors.directory' '2')
C_BRANCH=$(cfg '.colors.branch' '92')
C_VPN=$(cfg '.colors.vpn' '92')
C_WARN=$(cfg '.colors.warning' '93')
C_CRIT=$(cfg '.colors.critical' '91')
C_LABEL=$(cfg '.colors.label' '2')
T_WARN=$(cfg '.thresholds.warning' '50')
T_CRIT=$(cfg '.thresholds.critical' '80')
BAR_FILL=$(cfg '.bar.filled' '█')
BAR_EMPTY=$(cfg '.bar.empty' '░')
BAR_WIDTH=$(cfg '.bar.width' '10')
L_RATE=$(cfg '.labels.rate' 'auto')
L_CTX=$(cfg '.labels.context' 'ctx')
L_WEEK=$(cfg '.labels.weekly' 'auto')
L_CACHE=$(cfg '.labels.cache' 'cache')
WEEK_BAR=$(cfg '.weekly.bar' 'false')
CACHE_WARN_MIN=$(cfg '.cache.warn_minutes' '5')
CTX_ALERT=$(cfg '.context.alert_at' '80')
DISPLAY_MODE=$(cfg '.display.mode' 'used')
COLOR_RAMP=$(cfg '.display.color_ramp' 'same')
DIR_REL=$(cfg '.directory.relative_to' 'home')

RESET="\033[0m"

color() { printf "\033[%sm" "$1"; }

threshold_color() {
  local val=$(printf "%.0f" "$1") base="$2"
  if [ "$COLOR_RAMP" = "same" ]; then
    [ "$val" -ge "$T_CRIT" ] && printf "\033[1;%sm" "$base" && return
    [ "$val" -ge "$T_WARN" ] && color "$base" && return
    printf "\033[2;%sm" "$base"
  else
    [ "$val" -ge "$T_CRIT" ] && color "$C_CRIT" && return
    [ "$val" -ge "$T_WARN" ] && color "$C_WARN" && return
    color "$base"
  fi
}

display_pct() {
  local used="$1"
  if [ "$DISPLAY_MODE" = "remaining" ]; then
    echo "$(( 100 - $(printf "%.0f" "$used") ))"
  else
    printf "%.0f" "$used"
  fi
}

color_pct() { printf "%.0f" "$1"; }

bar() {
  local pct=$(printf "%.0f" "$1")
  local filled=$(( pct * BAR_WIDTH / 100 ))
  local empty=$(( BAR_WIDTH - filled ))
  local b="" i
  for (( i=0; i<filled; i++ )); do b="${b}${BAR_FILL}"; done
  for (( i=0; i<empty; i++ )); do b="${b}${BAR_EMPTY}"; done
  echo "$b"
}

# Render seconds-until-reset as a compact duration, e.g. 3d04h / 4h35m / 47m / <1m.
# `resets_at` is a Unix epoch timestamp supplied by Claude Code per rate-limit
# window. Returns empty on missing/non-numeric input so callers can fall back
# to the static window label.
format_countdown() {
  local target="$1" now remain d h m
  case "$target" in
    ''|*[!0-9]*) return ;;
  esac
  now=$(date +%s)
  remain=$(( target - now ))
  # Past the reset instant, the window has rolled over but the payload may not
  # have refreshed yet — show 0m rather than a negative duration.
  [ "$remain" -le 0 ] && { echo "0m"; return; }
  d=$(( remain / 86400 ))
  h=$(( remain / 3600 ))
  m=$(( (remain % 3600) / 60 ))
  # A day or more out (the weekly window), minutes are noise: show days+hours.
  if [ "$d" -gt 0 ]; then
    printf "%dd%02dh" "$d" $(( (remain % 86400) / 3600 ))
  elif [ "$h" -gt 0 ]; then
    printf "%dh%02dm" "$h" "$m"
  elif [ "$m" -gt 0 ]; then
    printf "%dm" "$m"
  else
    printf "<1m"
  fi
}

# Resolve a rate-gauge label. Modes: "auto" = the window name (5hr), "countdown"
# = time until reset (4h35m), anything else = that literal string. Countdown
# falls back to the window name if the payload carries no resets_at.
gauge_label() {
  local mode="$1" window_name="$2" resets="$3" countdown
  case "$mode" in
    auto) echo "$window_name" ;;
    countdown)
      countdown=$(format_countdown "$resets")
      echo "${countdown:-$window_name}"
      ;;
    *) echo "$mode" ;;
  esac
}

# Compact token count: 850 / 412k / 1.2M.
format_tokens() {
  local n="$1"
  case "$n" in
    ''|*[!0-9]*) return ;;
  esac
  if [ "$n" -ge 1000000 ]; then
    printf "%d.%dM" $(( n / 1000000 )) $(( (n % 1000000) / 100000 ))
  elif [ "$n" -ge 1000 ]; then
    printf "%dk" $(( n / 1000 ))
  else
    printf "%d" "$n"
  fi
}

short_dir() {
  local d="$1"
  case "$DIR_REL" in
    home) d="${d#$HOME/}" ;;
    none) ;;
    *)    d="${d#$DIR_REL/}" ;;
  esac
  echo "$d"
}

# Legacy fallback: infer a tier from thinking keywords in the latest prompt.
# Only used when `.effort.level` is absent from the payload — i.e. Claude Code
# older than the effort field, or a model that doesn't support the effort
# parameter. Maps onto the same low|medium|high|xhigh|max scale.
detect_thinking_legacy() {
  local tp="$1"
  if [ -z "$tp" ] || [ ! -f "$tp" ]; then
    echo "low"
    return
  fi
  # Scan only the tail of the transcript for performance (most-recent event
  # is at the bottom of the JSONL stream).
  local prompt
  prompt=$(tail -n 200 "$tp" 2>/dev/null | grep '"type":"last-prompt"' | tail -1 \
           | jq -r '.lastPrompt // empty' 2>/dev/null)
  if [ -z "$prompt" ]; then
    echo "low"
    return
  fi
  local p
  p=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')
  # Longest-keyword-first match (specificity wins over breadth).
  if echo "$p" | grep -qE '(ultrathink|ultra-think|megathink|mega-think)'; then
    echo "max"
  elif echo "$p" | grep -qE '(think really hard|think very hard|think a lot)'; then
    echo "xhigh"
  elif echo "$p" | grep -qE '(think harder|think hard|think more)'; then
    echo "high"
  elif echo "$p" | grep -qE '\bthink\b'; then
    echo "medium"
  else
    echo "low"
  fi
}

# Reasoning-effort tier, read straight from the payload Claude Code supplies.
# `.effort.level` is authoritative: it tracks the live session value including
# mid-session /effort changes, and reports ultracode as `xhigh`. The field is
# absent when the model doesn't support the effort parameter, in which case we
# fall back to keyword-sniffing the transcript.
# Pre-computed once — both 'thinking' and 'thinking_stars' segments read it.
thinking_level=$(echo "$input" | jq -r '.effort.level // empty')
case "$thinking_level" in
  low|medium|high|xhigh|max) ;;
  *) thinking_level=$(detect_thinking_legacy "$transcript_path") ;;
esac

# --- Build output from segments ---
out=""
sep=""

for seg in $SEGMENTS; do
  case "$seg" in
    vpn)
      if [[ "$OSTYPE" == darwin* ]]; then
        vpn_active=$(scutil --nc list 2>/dev/null | grep -c '(Connected)')
        if [ "$vpn_active" -gt 0 ]; then
          out="${out}${sep}$(printf "%b" "$(color "$C_VPN")◉${RESET}")"
        else
          out="${out}${sep}$(printf "%b" "\033[2;${C_VPN}m○${RESET}")"
        fi
        sep="  "
      fi
      ;;
    model)
      out="${out}${sep}$(printf "%b" "$(color "$C_MODEL")● ${model}${RESET}")"
      sep="  "
      ;;
    rate)
      if [ -n "$rate_pct" ]; then
        col=$(threshold_color "$(color_pct "$rate_pct")" "$C_RATE")
        show_pct=$(display_pct "$rate_pct")
        display_label=$(gauge_label "$L_RATE" "$rate_label" "$rate_resets")
        out="${out}${sep}$(printf "%b" "$(color "$C_LABEL")${display_label}:${RESET}${col}$(bar "$show_pct") ${show_pct}%${RESET}")"
        sep="  "
      fi
      ;;
    weekly)
      # Text-only by default so two rate gauges don't crowd the bar; set
      # `weekly.bar` to true for a full gauge.
      if [ -n "$week_pct" ]; then
        col=$(threshold_color "$(color_pct "$week_pct")" "$C_RATE")
        show_pct=$(display_pct "$week_pct")
        display_label=$(gauge_label "$L_WEEK" "7d" "$week_resets")
        gauge=""
        [ "$WEEK_BAR" = "true" ] && gauge="$(bar "$show_pct") "
        out="${out}${sep}$(printf "%b" "$(color "$C_LABEL")${display_label}:${RESET}${col}${gauge}${show_pct}%${RESET}")"
        sep="  "
      fi
      ;;
    context)
      if [ -n "$used_ctx" ]; then
        col=$(threshold_color "$(color_pct "$used_ctx")" "$C_CTX")
        # Close to compaction: switch to the critical colour whatever the
        # colour ramp, so it reads as an alarm rather than a brighter gauge.
        # Only when the gauge is measuring the compact window; 0 disables.
        if [ -n "$ctx_of_compact" ] && [ "$CTX_ALERT" -gt 0 ] 2>/dev/null \
           && [ "$(color_pct "$used_ctx")" -ge "$CTX_ALERT" ]; then
          col="\033[1;${C_CRIT}m"
        fi
        show_pct=$(display_pct "$used_ctx")
        out="${out}${sep}$(printf "%b" "$(color "$C_LABEL")${L_CTX}:${RESET}${col}$(bar "$show_pct") ${show_pct}%${RESET}")"
        sep="  "
      fi
      ;;
    cache)
      # Warm: time left before the cached prefix expires. Cold: the next
      # message re-pays for the whole conversation, so say how many tokens.
      if [ "$cache_observed" = "true" ]; then
        cache_left=""
        case "$cache_expires" in
          ''|*[!0-9]*) ;;
          *) cache_left=$(( cache_expires - $(date +%s) )) ;;
        esac
        # `warm` can lag the clock between renders; an expiry in the past is cold.
        if [ "$cache_warm" = "true" ] && { [ -z "$cache_left" ] || [ "$cache_left" -gt 0 ]; }; then
          cache_text=$(format_countdown "$cache_expires")
          cache_text="${cache_text:-warm}"
          if [ -n "$cache_left" ] && [ "$cache_left" -le $(( CACHE_WARN_MIN * 60 )) ]; then
            col=$(color "$C_WARN")
          else
            col="\033[2;${C_CACHE}m"
          fi
        else
          cache_text="cold"
          recache=$(format_tokens "$cache_recache")
          [ -n "$recache" ] && cache_text="cold ${recache}"
          col=$(color "$C_CRIT")
        fi
        seg_out="$(color "$C_LABEL")${L_CACHE}:${RESET}${col}${cache_text}${RESET}"
        # Misses are requests that re-processed content the cache already held.
        case "$cache_misses" in
          ''|0|*[!0-9]*) ;;
          *) seg_out="${seg_out} $(color "$C_WARN")${cache_misses}miss${RESET}" ;;
        esac
        out="${out}${sep}$(printf "%b" "$seg_out")"
        sep="  "
      fi
      ;;
    thinking)
      # Always-visible dot anchor. Color encodes effort intensity.
      case "$thinking_level" in
        max)    tcol="\033[1;95m" ;;
        xhigh)  tcol="\033[95m"   ;;
        high)   tcol="\033[35m"   ;;
        medium) tcol="\033[2;95m" ;;
        low)    tcol="\033[2m"    ;;
        *)      tcol=""            ;;
      esac
      if [ -n "$tcol" ]; then
        out="${out}${sep}$(printf "%b" "${tcol}·${RESET}")"
        sep="  "
      fi
      ;;
    thinking_stars)
      # Asterisk-count effort indicator. One star per effort level:
      # 1=low, 2=medium, 3=high (default), 4=xhigh, 5=max.
      # Yellow ramp: dim below the default, bright at or above it,
      # bold-bright at the ceiling.
      case "$thinking_level" in
        max)    stars="*****"; tcol="\033[1;93m" ;;
        xhigh)  stars="****";  tcol="\033[93m"   ;;
        high)   stars="***";   tcol="\033[93m"   ;;
        medium) stars="**";    tcol="\033[2;33m" ;;
        low)    stars="*";     tcol="\033[2;33m" ;;
        *)      stars="";      tcol=""            ;;
      esac
      if [ -n "$stars" ]; then
        out="${out}${sep}$(printf "%b" "${tcol}${stars}${RESET}")"
        sep="  "
      fi
      ;;
    directory)
      if [ -n "$cwd" ]; then
        out="${out}${sep}$(printf "%b" "$(color "$C_DIR")$(short_dir "$cwd")${RESET}")"
        sep="  "
      fi
      ;;
    branch)
      # `git -C ""` silently operates on the process's own working directory,
      # which would report an unrelated repo's branch when the payload carries
      # no current_dir. Require a directory before asking git anything.
      branch=""
      [ -n "$cwd" ] && branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
      if [ -n "$branch" ]; then
        # Git status indicators
        indicators=""
        git_status=$(git -C "$cwd" --no-optional-locks status --porcelain=v1 2>/dev/null)
        if [ -n "$git_status" ]; then
          # Staged (index has changes)
          echo "$git_status" | grep -q '^[MARCDU]' && indicators="${indicators}+"
          # Modified (unstaged changes)
          echo "$git_status" | grep -q '^.[MD]' && indicators="${indicators}!"
          # Untracked
          echo "$git_status" | grep -q '^??' && indicators="${indicators}?"
          # Deleted
          echo "$git_status" | grep -q '^[[:space:]]D\|^D' && indicators="${indicators}✘"
          # Conflicts
          echo "$git_status" | grep -q '^UU\|^AA\|^DD' && indicators="${indicators}×"
        fi
        # Stashed
        git -C "$cwd" --no-optional-locks stash list 2>/dev/null | grep -q . && indicators="${indicators}⚑"
        # Ahead / behind / diverged
        counts=$(git -C "$cwd" --no-optional-locks rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null)
        if [ -n "$counts" ]; then
          behind=$(echo "$counts" | awk '{print $1}')
          ahead=$(echo "$counts" | awk '{print $2}')
          [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ] && indicators="${indicators}⇕" ||
          { [ "$ahead" -gt 0 ] && indicators="${indicators}⇡"; [ "$behind" -gt 0 ] && indicators="${indicators}⇣"; }
        fi
        # Render
        branch_str="${branch}"
        [ -n "$indicators" ] && branch_str="${branch} ${indicators}"
        out="${out}${sep}$(printf "%b" "$(color "$C_BRANCH")ᚦ ${branch_str}${RESET}")"
        sep="  "
      fi
      ;;
  esac
done

printf "%b\n" "$out"

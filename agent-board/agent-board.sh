#!/usr/bin/env bash
# Agent board: a desktop-region demo for Herdr.
# Lists every agent in the session with its status, refreshes every 2 seconds,
# and focuses an agent when you press its number. Needs bash and jq.
#
#   agent-board.sh          run the board (what the region runs)
#   agent-board.sh --once   print one frame and exit (for testing)

set -u

HERDR="${HERDR_BIN_PATH:-herdr}"
# The region entrypoint this copy runs as: "board" (right edge) or "strip"
# (bottom edge). The strip is short, so it puts each agent on one line.
ENTRYPOINT="${HERDR_PLUGIN_ENTRYPOINT_ID:-board}"
COMPACT=0
[ "$ENTRYPOINT" = strip ] && COMPACT=1
REFRESH_SECONDS=2
ONCE=0
[ "${1:-}" = "--once" ] && ONCE=1

if ! command -v jq >/dev/null 2>&1; then
  printf 'agent board needs jq on PATH\n'
  exec sleep 2147483647
fi

# Colours only when writing to a terminal.
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
else
  BOLD=; DIM=; RESET=; RED=; GREEN=; YELLOW=
fi

PANES=()

# Read the width from the terminal itself: render runs in a subshell whose
# stdout is a pipe, so tput would fall back to 80 columns.
width() {
  local size cols
  size=$(stty size </dev/tty 2>/dev/null) || size=
  cols=${size#* }
  [ "$cols" -gt 0 ] 2>/dev/null || cols=${COLUMNS:-34}
  [ "$cols" -gt 0 ] 2>/dev/null || cols=34
  printf '%s' "$cols"
}

# Cut text to N columns, marking the cut with an ellipsis.
fit() {
  local text=$1 max=$2
  if [ "${#text}" -gt "$max" ]; then
    printf '%s…' "${text:0:$((max - 1))}"
  else
    printf '%s' "$text"
  fi
}

status_style() {
  case $1 in
    blocked) printf '%s●%s' "$RED" "$RESET" ;;
    working) printf '%s●%s' "$YELLOW" "$RESET" ;;
    done) printf '%s●%s' "$GREEN" "$RESET" ;;
    idle) printf '%s○%s' "$DIM" "$RESET" ;;
    *) printf '%s?%s' "$DIM" "$RESET" ;;
  esac
}

# One tab-separated row per agent: pane_id, status, name, workspace label, cwd.
# Blocked agents first, then working, done, idle.
agent_rows() {
  local agents workspaces
  agents=$("$HERDR" agent list 2>/dev/null) || return 1
  workspaces=$("$HERDR" workspace list 2>/dev/null) || workspaces='{}'
  jq -r --argjson ws "$workspaces" '
    ($ws.result.workspaces // [] | map({key: .workspace_id, value: .label}) | from_entries) as $labels
    | def rank: {"blocked":0,"working":1,"done":2,"idle":3}[.] // 4;
    .result.agents // []
    | sort_by((.agent_status | rank), .workspace_id, .pane_id)
    | .[]
    | [ .pane_id,
        (.agent_status // "unknown"),
        (.name // .agent // .terminal_title_stripped // "agent"),
        ($labels[.workspace_id] // .workspace_id // ""),
        ((.foreground_cwd // .cwd // "") | split("/") | last) ]
    | @tsv' <<<"$agents"
}

render() {
  local cols rows n=0 blocked=0 line
  cols=$(width)
  PANES=()
  if ! rows=$(agent_rows); then
    printf '%sagent board%s\n%scannot reach herdr%s\n' "$BOLD" "$RESET" "$RED" "$RESET"
    return
  fi
  local body=""
  while IFS=$'\t' read -r pane status name workspace cwd; do
    [ -n "$pane" ] || continue
    n=$((n + 1))
    PANES+=("$pane")
    [ "$status" = blocked ] && blocked=$((blocked + 1))
    local key=" "
    [ "$n" -le 9 ] && key=$n
    if [ "$COMPACT" -eq 1 ]; then
      local where=" · $workspace · $cwd"
      line="$(printf '%s%s%s %s %s' "$BOLD" "$key" "$RESET" "$(status_style "$status")" "$(fit "$name$where" $((cols - 5)))")"
      body+="$line"$'\n'
    else
      line="$(printf '%s%s%s %s %s' "$BOLD" "$key" "$RESET" "$(status_style "$status")" "$(fit "$name" $((cols - 5)))")"
      body+="$line"$'\n'
      body+="    $DIM$(fit "$workspace · $cwd" $((cols - 5)))$RESET"$'\n'
    fi
  done <<<"$rows"

  local header="Agents $n"
  [ "$blocked" -gt 0 ] && header+=" · $RED$blocked blocked$RESET$BOLD"
  if [ "$COMPACT" -eq 1 ]; then
    printf '%s%s%s  %s1-9 jump · r refresh · h hide%s\n' "$BOLD" "$header" "$RESET" "$DIM" "$RESET"
  else
    printf '%s%s%s\n' "$BOLD" "$header" "$RESET"
    printf '%s%s%s\n' "$DIM" "$(printf '%*s' "$cols" '' | tr ' ' '-')" "$RESET"
  fi
  if [ "$n" -eq 0 ]; then
    printf '%sno agents running%s\n' "$DIM" "$RESET"
  else
    printf '%s' "$body"
  fi
  [ "$COMPACT" -eq 1 ] || printf '\n%s1-9 jump · r refresh · h hide%s\n' "$DIM" "$RESET"
}

my_region_id() {
  "$HERDR" region list 2>/dev/null | jq -r --arg plugin "${HERDR_PLUGIN_ID:-demo.agent-board}" --arg entrypoint "$ENTRYPOINT" \
    '.result.regions // [] | map(select(.plugin_id == $plugin and .entrypoint == $entrypoint)) | .[0].region_id // empty'
}

if [ "$ONCE" -eq 1 ]; then
  render
  exit 0
fi

FRAME_FILE=$(mktemp "${TMPDIR:-/tmp}/agent-board.XXXXXX")
trap 'rm -f "$FRAME_FILE"; tput cnorm 2>/dev/null; exit 0' INT TERM EXIT
tput civis 2>/dev/null
while :; do
  # Render into a temp file, not $(render): a subshell would drop PANES.
  render >"$FRAME_FILE"
  printf '\033[H\033[2J%s' "$(cat "$FRAME_FILE")"
  key=
  IFS= read -rsn1 -t "$REFRESH_SECONDS" key || true
  case $key in
    [1-9])
      pane=${PANES[$((key - 1))]:-}
      [ -n "$pane" ] && "$HERDR" agent focus "$pane" >/dev/null 2>&1
      ;;
    h)
      region=$(my_region_id)
      [ -n "$region" ] && "$HERDR" region hide "$region" >/dev/null 2>&1
      ;;
  esac
done

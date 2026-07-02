#!/usr/bin/env bash
# Emit the current MPRIS track for Waybar, scrolling long titles.
#
# Outputs one JSON object per line (Waybar `return-type: json`). Runs
# continuously: polls playerctl and, when "artist - title" is longer than
# MAX_LEN, scrolls it one character at a time.

MAX_LEN=40          # characters shown before scrolling kicks in
SEPARATOR="   "     # gap between the end and the wrapped-around start
TICK=0.3            # seconds between scroll steps
PLAY_ICON=""
PAUSE_ICON=""

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

emit_empty() {
  printf '{"text": "", "tooltip": ""}\n'
}

# Echo "<player>\t<status>" for the most relevant player: a Playing one if
# any, otherwise the first Paused one. Bare `playerctl status` just grabs the
# first player (often a stopped browser tab), so inspect each explicitly.
pick_player() {
  local players player status paused=""
  players=$(playerctl -l 2>/dev/null) || return 1
  [ -z "$players" ] && return 1
  while IFS= read -r player; do
    [ -z "$player" ] && continue
    status=$(playerctl --player="$player" status 2>/dev/null)
    if [ "$status" = "Playing" ]; then
      printf '%s\t%s' "$player" "$status"
      return 0
    fi
    if [ "$status" = "Paused" ] && [ -z "$paused" ]; then
      paused=$player
    fi
  done <<< "$players"
  [ -n "$paused" ] && { printf '%s\t%s' "$paused" "Paused"; return 0; }
  return 1
}

scroll_pos=0
last_text=""

while true; do
  if ! result=$(pick_player); then
    if [ -n "$last_text" ]; then emit_empty; last_text=""; fi
    sleep 1
    continue
  fi

  player=${result%%$'\t'*}
  status=${result##*$'\t'}

  meta=$(playerctl --player="$player" metadata --format $'{{artist}}\t{{title}}' 2>/dev/null)
  artist=${meta%%$'\t'*}
  title=${meta##*$'\t'}

  if [ -n "$artist" ] && [ -n "$title" ]; then
    text="$artist - $title"
  else
    text="${artist}${title}"
  fi

  if [ -z "$text" ]; then
    if [ -n "$last_text" ]; then emit_empty; last_text=""; fi
    sleep 1
    continue
  fi

  # Reset scroll position when the track changes.
  if [ "$text" != "$last_text" ]; then
    scroll_pos=0
    last_text="$text"
  fi

  if [ "$status" = "Paused" ]; then
    prefix="$PAUSE_ICON  "
  else
    prefix="$PLAY_ICON  "
  fi

  tooltip=$(json_escape "$text")

  if [ ${#text} -le $MAX_LEN ]; then
    out=$(json_escape "$prefix$text")
    printf '{"text": "%s", "tooltip": "%s"}\n' "$out" "$tooltip"
    sleep 1
    continue
  fi

  # Scroll: build a ring buffer and take a MAX_LEN-wide window.
  ring="$text$SEPARATOR"
  double="$ring$ring"
  window=${double:$scroll_pos:$MAX_LEN}
  scroll_pos=$(( (scroll_pos + 1) % ${#ring} ))

  out=$(json_escape "$prefix$window")
  printf '{"text": "%s", "tooltip": "%s"}\n' "$out" "$tooltip"
  sleep "$TICK"
done

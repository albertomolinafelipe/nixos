#!/usr/bin/env bash
# Emit today's Obsidian daily-note progress for Waybar (return-type: json).
#
# Below GOAL words -> flashing "ESCRIBE" plus a 10-block bar, both in the
# blinking red from the CSS. At or above GOAL -> obsidian icon and a green bar.

DIR="${DAYLOG_DIR:-$HOME/Sync/Obsidian/db_logs/days}"
GOAL="${DAYLOG_GOAL:-500}"

FILE="$DIR/$(date +%F).md"

GREEN="#98bb6c"

if [ -f "$FILE" ]; then
  words=$(wc -w <"$FILE")
else
  words=0
fi

filled=$((words * 10 / GOAL))
[ "$filled" -gt 10 ] && filled=10

bar=""
[ "$filled" -eq 0 ] && bar="━"
for ((i = 0; i < filled; i++)); do bar+="■"; done

# Under the goal the bar takes its colour from the blinking .missing CSS, so it
# pulses in step with ESCRIBE.
if [ "$words" -lt "$GOAL" ]; then
  printf '{"text": "ESCRIBE <span size=\x278pt\x27>%s</span>", "tooltip": "%d / %d words", "class": "missing"}\n' \
    "$bar" "$words" "$GOAL"
  exit 0
fi

printf '{"text": "<span size=\x279pt\x27>\ue6bb</span> <span size=\x278pt\x27 color=\x27%s\x27>%s</span>", "tooltip": "%d / %d words", "class": "reached"}\n' \
  "$GREEN" "$bar" "$words" "$GOAL"

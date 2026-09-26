#!/usr/bin/env bash
# Emit today's Obsidian daily-note progress for Waybar (return-type: json).
#
# Missing note -> class "missing" (CSS blinks it). Existing note -> a 10-block
# bar filled by word count against GOAL.

DIR="${DAYLOG_DIR:-$HOME/Sync/Obsidian/db_logs/days}"
GOAL="${DAYLOG_GOAL:-500}"

FILE="$DIR/$(date +%F).md"

COLORS=(
  "#df6124" "#df6124" "#dd7006" "#d88000" "#d09000"
  "#c5a000" "#b5af00" "#a2be00" "#8acc00" "#68da00" "#25e712"
)

if [ ! -f "$FILE" ]; then
  printf '{"text": "ESCRIBE", "tooltip": "No note for today", "class": "missing"}\n'
  exit 0
fi

words=$(wc -w <"$FILE")

filled=$((words * 10 / GOAL))
[ "$filled" -gt 10 ] && filled=10

bar=""
[ "$filled" -eq 0 ] && bar="━"
for ((i = 0; i < filled; i++)); do bar+="■"; done

if [ "$filled" -ge 10 ]; then class=reached; else class=writing; fi

printf '{"text": "<span size=\x279pt\x27></span> <span size=\x278pt\x27 color=\x27%s\x27>%s</span>", "tooltip": "%d words (goal %d)", "class": "%s"}\n' \
  "${COLORS[$filled]}" "$bar" "$words" "$GOAL" "$class"

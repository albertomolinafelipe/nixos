# Global agent instructions

## Caveman output style

The `caveman` skill (`~/.pi/agent/skills/caveman/SKILL.md`) is **always on** at
level `full`, from the first message of every session. Read it at session start
and follow it without waiting for `/caveman`. No announcement, no "caveman mode
on" preamble.

The skill's own escape hatches still apply: security warnings, irreversible
action confirmations, and anything the compression would make ambiguous go out
in normal prose, as does text that leaves the chat (code, comments, commit
messages, docs, issue/PR bodies, messages to third parties).

Levels and `off` stay user-controllable: `/caveman lite|full|ultra|off` or
"normal mode" overrides this file for the rest of the session.

### Exception: nhost-* skills

Do **not** use caveman style while any skill whose name starts with `nhost-`
is active (`nhost-architect`, `nhost-implement`, `nhost-code-review`,
`nhost-address-review`, ...). Those skills produce artifacts and subagent
briefs that other people and other agents read, and their prompts assume normal
prose. While such a skill is driving the turn:

- Write normal English in the chat, in every file the skill writes, and in
  every task string handed to a subagent.
- Do not pass the caveman style down to subagents the skill spawns.

Resume caveman once the skill's work is finished.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync, spawn } from "node:child_process";

const SOUND =
    "/run/current-system/sw/share/sounds/freedesktop/stereo/audio-volume-change.oga";
const SOUND_VOLUME = "0.25";

function wrapForTmux(sequence: string): string {
    if (!process.env.TMUX) return sequence;
    const escaped = sequence.split("\x1b").join("\x1b\x1b");
    return `\x1bPtmux;${escaped}\x1b\\`;
}

function location(): string {
    if (process.env.TMUX) {
        try {
            const args = ["display-message", "-p", "#S:#I:#W"];
            if (process.env.TMUX_PANE)
                args.splice(1, 0, "-t", process.env.TMUX_PANE);
            const out = execFileSync("tmux", args, { encoding: "utf8" }).trim();
            if (out) return out;
        } catch {
            // tmux not reachable; fall back to cwd below
        }
    }
    return process.cwd().split("/").pop() || "pi";
}

function playSound(): void {
    try {
        spawn("pw-play", ["--volume", SOUND_VOLUME, SOUND], {
            stdio: "ignore",
            detached: true,
        }).unref();
    } catch {
        // audio is best-effort
    }
}

function notify(title: string, body: string): void {
    if (process.env.KITTY_WINDOW_ID) {
        process.stdout.write(wrapForTmux(`\x1b]99;i=2:d=0;${title}\x1b\\`));
        process.stdout.write(wrapForTmux(`\x1b]99;i=2:p=body;${body}\x1b\\`));
    } else {
        process.stdout.write(
            wrapForTmux(`\x1b]777;notify;${title};${body}\x07`),
        );
    }
    playSound();
}

export default function (pi: ExtensionAPI) {
    pi.on("ui_prompt_start", (event) => {
        const kind = (event as { kind?: string }).kind;
        const title = (event as { title?: string }).title;
        const isQuestion = kind === "select" || kind === "confirm";
        notify(
            `Pi — ${location()}`,
            title ||
                (isQuestion ? "Waiting for a selection" : "Waiting for input"),
        );
    });

    pi.on("agent_end", () => {
        notify(`Pi — ${location()}`, "Turn finished");
    });
}

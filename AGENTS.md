# AGENTS.md

Personal NixOS + home-manager flake for a single machine (hostname `nixos`,
user `alberto`). Hyprland desktop, Kanagawa theme everywhere, plus a
declarative Secureframe/SOC2 compliance layer.

## Layout

| Path | What it is |
| --- | --- |
| `flake.nix` | Single output: `nixosConfigurations.nixos`. Inputs passed to modules via `specialArgs.inputs`. |
| `configuration.nix` | System: boot/LUKS, networking, docker, greetd, hyprland, fonts, locale, users. Imports hardware config + home-manager. |
| `hardware-configuration.nix` | Generated. Don't hand-edit. |
| `home.nix` | Everything user-level: packages, shell (zsh/starship/zoxide), tmux, kitty, git, waybar, hyprlock/hypridle/hyprpaper, mako, k9s, opencode. |
| `nixvim-configuration.nix` | Neovim via nixvim, imported from `home.nix`. |
| `secureframe.nix` | Compliance module (osquery + mitmproxy + SOC2 hardening). Imported directly by the flake. |
| `secureframe/` | Docs + tooling for the above: `README.md`, `extract.py`, `proxy.py`, `versions.toml`/`versions.nix`. |
| `pkgs/` | Local derivations (`coding-agents-tmux.nix`, `fleetd-tables.nix`) and `secureframe.py`, the proxy script the systemd unit actually runs. |
| `pi/` | Pi coding-agent config deployed to `~/.pi/agent` by `home.nix`: global `AGENTS.md` context file and the vendored `skills/caveman` skill. |
| `hypr/hyprland.lua` | Hyprland config in Lua, symlinked to `~/.config/hypr/hyprland.lua`. Not managed by the home-manager hyprland module (`systemd.enable = false`). |
| `waybar/` | `config.jsonc`, `style.css`, and helper scripts, symlinked into `~/.config/waybar`. |
| `secrets/secureframe.yaml` | sops-encrypted, keyed per hostname. |

## Build and apply

```sh
sudo nixos-rebuild switch --flake ~/nixos   # alias: nrb
nix flake update                            # all inputs
nix flake update sops-nix                   # one input
sudo nix-collect-garbage -d                 # alias: ncg
```

Build without activating to check an edit:

```sh
nix build ~/nixos#nixosConfigurations.nixos.config.system.build.toplevel --no-link
```

The tree is a git repo and the flake is `git+file:`, so **new files must be
`git add`-ed before Nix can see them**. A dirty tree only produces a warning.

## Conventions

- Two-space indent, `{ inputs, config, lib, pkgs, ... }:` argument lists,
  trailing semicolons. Some older lines use tabs — don't reformat them
  wholesale, just match the block you're editing.
- Prefer a home-manager `programs.*`/`services.*` module over dropping raw
  dotfiles. Use `xdg.configFile."x".source = ./x;` only where no module
  exists (hyprland, waybar).
- Non-obvious settings carry a comment explaining *why* (see the
  `bridge-nf-call-iptables`, docker `containerd-snapshotter`, and
  `allow-passthrough` blocks). Keep that habit — most of the tricky lines here
  are workarounds and lose their meaning without it.
- Colors are Kanagawa hex literals (`#dcd7ba` fg, `#2a2a37` bg/status,
  `#e6c384` accent). Reuse the existing values instead of inventing new ones.
- Third-party sources are pinned by rev + hash. `fleetd-tables` reads
  `secureframe/versions.toml`; bump versions there, not in the `.nix`.

## Pi agent config (`pi/`, `home.nix`)

`home.nix` writes three things into `~/.pi/agent` with `home.file`:

- `AGENTS.md` ← `pi/AGENTS.md`. Global pi context, loaded before any project
  `AGENTS.md`. Enables the caveman output style by default and exempts the
  `nhost-*` skills, whose artifacts other people read.
- `skills/caveman` ← `pi/skills/caveman`. Vendored from
  github.com/JuliusBrussee/caveman (`plugins/caveman/skills`). Update by
  re-copying, not by editing upstream in place.
- `ext/claude-bridge.ts` ← the `piClaudeBridgeExtension` derivation, which digs
  `pi-claude-bridge/src/index.ts` out of the `nhost-code-agent` store path by
  grepping the `nhost-code` launcher (the flake doesn't expose the agent as an
  output). Needed because `pi-subagents` runs foreground children with
  `noExtensions`, so without a child-only copy of the bridge every foreground
  subagent on a claude-bridge model dies with `prompt-capture: no capture for
  this N-char system prompt`.

The setting that points at that extension —
`subagents.defaultSubagentOnlyExtensions` in `~/.pi/agent/settings.json` — is
**not** managed here: pi rewrites that file, so home-manager can't own it. It
references the stable `~/.pi/agent/ext/claude-bridge.ts` symlink rather than a
version-pinned store path, so a `nhost-be` bump doesn't break it.

## Things that will bite you

- **Don't install tools outside Nix.** `claude-code` and friends come from
  `home.nix`; running an upstream self-updater (e.g. `claude update`) creates a
  shadowed second copy under `~/.local`. Bump `nixpkgs` instead.
- **`flake.lock` can end up root-owned** after a `sudo` command writes it,
  which makes `nix flake update` fail with `Permission denied`. Fix with
  `sudo chown alberto:users flake.lock`.
- **Input bumps couple to nixpkgs.** All inputs `follows` nixpkgs, so a
  nixpkgs jump can break a stale input (a recent one: sops-nix pinned to
  `buildGo125Module` after nixpkgs removed it). If an input's package fails to
  evaluate after `nix flake update`, update that input too.
- **Local path inputs**: `nhost-be` and `nhost` are `git+file:` checkouts under
  `~/code`. They must exist and be committed for evaluation to succeed.
- **sops**: decryption needs `/var/lib/sops-nix/key.txt` (root-owned, outside
  the store, installed once per machine). Missing key = activation failure.
- `nix.settings.sandbox = "relaxed"` is required by the nhost agent's
  `__noChroot` derivation. Leave it.

## Compliance invariants (`secureframe.nix`, parts of `home.nix`)

This machine is audited. Do not weaken these without a compliance review:

- `networking.firewall.enable = true`
- 15-minute `services.hypridle` lock + dpms timeouts, backed by hyprlock
- ClamAV daemon/updater, PAM `maxlogins` and pwquality rules
- LUKS root device in `configuration.nix`

The osquery setup talks to Secureframe through a local mitmproxy on `:4443`
(`pkgs/secureframe.py`) that injects the enroll secret and allowlists
distributed queries. `specifiedIdentifier` is **per-device** — regenerate it
with `secureframe/extract.py` on that device's `.deb` when provisioning a new
machine. The `ufw` unit, dpkg status entry, and `/opt/osquery` tmpfiles are
deliberate shims for Debian-only checks; they are not real software.

Note `secureframe/proxy.py` and `pkgs/secureframe.py` are currently identical
copies; only the `pkgs/` one is wired into the systemd unit.

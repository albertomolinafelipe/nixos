{ inputs, config, pkgs, ... }:

let
  # Prints $PWD with $HOME as ~, keeping only the last 8 path components
  # (prefixed with ../ when truncated) to mirror the old directory module.
  starshipDirCmd = ''
    case "$PWD" in
      "$HOME") dir="~" ;;
      "$HOME"/*) dir="~/''${PWD#$HOME/}" ;;
      *) dir="$PWD" ;;
    esac
    oldIFS=$IFS; IFS=/; parts=($dir); IFS=$oldIFS
    if [ "''${#parts[@]}" -gt 8 ]; then
      IFS=/; dir="../''${parts[*]: -8}"; IFS=$oldIFS
    fi
    printf '%s' "$dir"
  '';
  starshipDirShell = [ "bash" "--noprofile" "--norc" ];

  nhostCode = inputs.nhost-be.packages.${pkgs.stdenv.hostPlatform.system}.nhost-code;
  # pi-subagents runs foreground children with `noExtensions`, so pi-claude-bridge
  # never loads inside them and never records their system prompt in its
  # prompt-capture map. The child's query still reaches the parent's bridge
  # instance (providers are inherited), which refuses an unknown prompt rather
  # than silently dropping that turn's context files and instructions — so every
  # foreground subagent on a claude-bridge model dies with "prompt-capture: no
  # capture for this N-char system prompt". Loading the bridge as a child-only
  # extension restores the capture. The setting itself lives in
  # ~/.pi/agent/settings.json (subagents.defaultSubagentOnlyExtensions); pi
  # rewrites that file, so home-manager can't own it, and it points at the stable
  # symlink below instead of a version-pinned store path.
  # `nhost-code` is a wrapper around a separate nhost-code-agent store path that
  # the flake does not expose as an output, so dig it out of the launcher.
  piClaudeBridgeExtension = pkgs.runCommand "pi-claude-bridge-extension" { } ''
    agent=$(grep -om1 '/nix/store/[^ "]*-nhost-code-agent-[^/ "]*' ${nhostCode}/bin/nhost-code)
    ext="$agent/libexec/pi/node_modules/pi-claude-bridge/src/index.ts"
    test -f "$ext"
    ln -s "$ext" $out
  '';
in
{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./nixvim-configuration.nix
  ];

  home.username = "alberto";
  home.homeDirectory = "/home/alberto";
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.packages = with pkgs; [
    # Internal nhost CLI
    inputs.nhost-be.packages.${pkgs.stdenv.hostPlatform.system}.nhost-code
    inputs.nhost-be.packages.${pkgs.stdenv.hostPlatform.system}.gha
    inputs.nhost.packages.${pkgs.stdenv.hostPlatform.system}.ghactivity

    claude-code
    gh 
    awscli

    firefox
    spotify
    obsidian
    keepassxc
    discord
    signal-desktop
    whatsie
    calibre

    waybar
    playerctl
    bemenu

    # utilities
    hyprshot

    # terminal
    gcc
    tree
    htop
    eza
    ripgrep
    lazygit
    gnumake
    kubectl
  ];

  home.pointerCursor = {
    gtk.enable = true;
    hyprcursor.enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
  };

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    font = {
      name = "Hack Nerd Font";
      size = 10;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };
  
  xdg.configFile."hypr/hyprland.lua".source = ./hypr/hyprland.lua;

  # Referenced by subagents.defaultSubagentOnlyExtensions in
  # ~/.pi/agent/settings.json — see piClaudeBridgeExtension above.
  home.file.".pi/agent/ext/claude-bridge.ts".source = piClaudeBridgeExtension;

  # Global pi context file (loaded from the agent dir before any project
  # AGENTS.md): turns the caveman skill below on by default and carves out the
  # nhost-* skills, whose artifacts are read by other people.
  home.file.".pi/agent/AGENTS.md".source = ./pi/AGENTS.md;
  # Vendored from github.com/JuliusBrussee/caveman (plugins/caveman/skills).
  home.file.".pi/agent/skills/caveman".source = ./pi/skills/caveman;


  programs.k9s = {
    enable = true;
    settings = {
      k9s = {
        liveViewAutoRefresh = false;
        gpuVendors = { };
        screenDumpDir = "/home/alberto/.local/state/k9s/screen-dumps";
        refreshRate = 2;
        apiServerTimeout = "2m0s";
        maxConnRetry = 5;
        readOnly = false;
        noExitOnCtrlC = false;
        portForwardAddress = "localhost";
        ui = {
          skin = "kanagawa";
        };
        skipLatestRevCheck = false;
        disablePodCounting = false;
        shellPod = {
          image = "busybox:1.37.0";
          namespace = "default";
          limits = {
            cpu = "100m";
            memory = "100Mi";
          };
        };
        imageScans = {
          enable = false;
          exclusions = {
            namespaces = [ ];
            labels = { };
          };
        };
        logger = {
          tail = 100;
          buffer = 5000;
          sinceSeconds = -1;
          textWrap = false;
          disableAutoscroll = false;
          columnLock = false;
          showTime = false;
        };
        thresholds = {
          cpu = {
            critical = 90;
            warn = 70;
          };
          memory = {
            critical = 90;
            warn = 70;
          };
        };
        defaultView = "";
      };
    };
    aliases = {
      dp = "deployments";
      sec = "v1/secrets";
      jo = "jobs";
      cr = "clusterroles";
      crb = "clusterrolebindings";
      ro = "roles";
      rb = "rolebindings";
      np = "networkpolicies";
    };
  };
  wayland.windowManager.hyprland.systemd.enable = false;

  # Owns org.freedesktop.Notifications, which kitty needs to render the
  # OSC 99 notification pi-notify emits when a turn finishes.
  services.mako = {
    enable = true;
    settings = {
      background-color = "#2a2a37";
      icons = false;
      text-color = "#dcd7ba";
      border-color = "#e6c384";
      border-size = 2;
      border-radius = 4;
      font = "GohuFont 14 Nerd Font 10.5";
      padding = "10";
      default-timeout = 8000;
      anchor = "top-right";
    };
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      preload = [
	"~/nixos/bg.png"
      ];
      wallpaper = [
        {
	  monitor = "";
	  path = "~/nixos/bg.png"; 
	}
      ];
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 0;
      };

      background = [{
        path = "~/nixos/bg.png";
        blur_passes = 2;
        blur_size = 4;
      }];

      input-field = [{
        size = "250, 50";
        position = "0, -80";
        halign = "center";
        valign = "center";
        outline_thickness = 1;
        dots_size = 0.25;
        dots_spacing = 0.3;
        outer_color = "rgb(e6c384)";
        inner_color = "rgb(1f1f28)";
        font_color = "rgb(dcd7ba)";
        check_color = "rgb(c0a36e)";
        fail_color = "rgb(c34043)";
        placeholder_text = "";
        fade_on_empty = false;
        rounding = 3;
      }];

      label = [{
        text = "$TIME";
        color = "rgb(dcd7ba)";
        font_size = 64;
        font_family = "Hack Nerd Font";
        position = "0, 80";
        halign = "center";
        valign = "center";
      }];
    };
  };

  # SOC2: 15-minute inactivity auto-lock and screen-off. Do not relax the
  # timeouts without a compliance review. Uses hyprlock (configured above).
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 15 * 60;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 15 * 60;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  programs.waybar.enable = true;
  xdg.configFile."waybar/config.jsonc".source = ./waybar/config.jsonc;
  xdg.configFile."waybar/style.css".source = ./waybar/style.css;
  xdg.configFile."waybar/scrolling-mpris.sh" = {
    source = ./waybar/scrolling-mpris.sh;
    executable = true;
  };
  xdg.configFile."waybar/daylog.sh" = {
    source = ./waybar/daylog.sh;
    executable = true;
  };

  programs.kitty = {
    enable = true;
    themeFile = "kanagawa";
    settings.enable_audio_bell = false;
    font = {
      name = "Hack Nerd Font Mono";
      size = 9;
    };
    keybindings = {
      "ctrl+minus" = "change_font_size all -1.0";
      "ctrl+plus" = "change_font_size all +1.0";
      "ctrl+0" = "change_font_size all 0";
    };
  };

  programs.tmux = {
    enable = true;
    prefix = "C-b";
    baseIndex = 1;
    keyMode = "vi";
    mouse = true;
    escapeTime = 0;
    historyLimit = 10000;
    terminal = "tmux-256color";
    plugins = [
      pkgs.tmuxPlugins.vim-tmux-navigator
      {
        plugin = pkgs.callPackage ./pkgs/coding-agents-tmux.nix { };
        extraConfig = ''
          set -g @coding-agents-tmux-provider 'plugin'
          set -g @coding-agents-tmux-auto-install 'opencode,pi,codex,claude'
          set -g @coding-agents-tmux-menu-key 'a'
          set -g @coding-agents-tmux-popup-key 'P'
          set -g @coding-agents-tmux-waiting-menu-key 'W'
          set -g @coding-agents-tmux-waiting-popup-key 'C-w'
          set -g @coding-agents-tmux-status 'on'
          set -g @coding-agents-tmux-status-style 'tmux'
          set -g @coding-agents-tmux-status-position 'right'
          set -g @coding-agents-tmux-status-interval '0'

          set -g @coding-agents-tmux-status-color-neutral '#c8c093'
          set -g @coding-agents-tmux-status-color-idle '#c8c093'
          set -g @coding-agents-tmux-status-color-busy '#7fb4ca'
          set -g @coding-agents-tmux-status-color-waiting '#e6c384'
          set -g @coding-agents-tmux-status-color-unknown '#938aa9'
        '';
      }
    ];
    extraConfig = ''
      # true color passthrough
      set -ag terminal-overrides ",xterm-kitty:RGB"

      # let agents' OSC notification sequences reach kitty
      set -g allow-passthrough on

      # kanagawa status bar background
      set -g status-style "bg=#2a2a37,fg=#dcd7ba"

      # center the window list
      set -g status-justify centre

      # kanagawa window styling
      set -g status-left "#[fg=#2a2a37,bg=#e6c384,bold] #S #[fg=#e6c384,bg=#2a2a37]"
      set -g status-left-length 30
      set -g status-right "#{E:@coding-agents-tmux-status-format} #[fg=#54546d]%H:%M "

      # inactive windows: muted
      set -g window-status-format "#[fg=#727169] #I:#W "
      # active window: kanagawa yellow accent, [Z] when zoomed
      set -g window-status-current-format "#[fg=#2a2a37,bg=#e6c384,bold] #I:#W#{?window_zoomed_flag, [Z],} "
      set -g window-status-separator ""

      # pane border same color as status bar background
      set -g pane-border-style "fg=#2a2a37"
      set -g pane-active-border-style "fg=#2a2a37"

      # vim-tmux-navigator steals C-l for pane navigation;
      # restore clear-screen under the prefix (C-Space C-l)
      bind C-l send-keys 'C-l'

      # new panes inherint cwd
      bind '"' split-window -c "#{pane_current_path}"
      bind %   split-window -h -c "#{pane_current_path}"

      # vim-style split names: v splits side-by-side, h stacks
      # (tmux's own -h/-v flags mean the opposite, hence the swap)
      bind v split-window -h -c "#{pane_current_path}"
      bind h split-window -v -c "#{pane_current_path}"

      # floating lazygit (no border)
      set -g popup-border-lines none
      bind g display-popup -E -w 80% -h 80% -d "#{pane_current_path}" lazygit

      # prefix-d shows running containers instead of detaching
      unbind d
      bind d display-popup -E -w 80% -h 80% "docker ps; read -r -s -n 1"

      bind k kill-window
    '';
  };

  programs.git = {
    enable = true;
    settings.user.name = "albertomolinafelipe";
    settings.user.email = "albmf@protonmail.com";
    settings.init.defaultBranch = "main";
    settings.push.autoSetupRemote = "true";
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history.size = 1000;
    shellAliases = {
      ncg = "sudo nix-collect-garbage -d";
      nrb = "sudo nixos-rebuild switch --flake ~/nixos";
      nd = "nix develop -c zsh";
      l = "eza -l --icons --git --sort=Extension";
      v = "nvim";
      q = "exit";
      k = "kubectl";
      gst = "git status";
      gwt = "git worktree";
      ga = "git add";
      glo = "git log --oneline";
      lg = "lazygit";
      k9s = "k9s --readonly";
      # nhost-code-agent's launcher omits coding-agents-tmux, so the pane-state
      # extension needs an explicit -e
      pi = "nhost-code -e $HOME/.pi/agent/extensions/coding-agents-tmux/index.ts";
    };
    initContent = ''
      bindkey -v

      wtfcpu() {
        ps -eo pid,%cpu,comm --sort=-%cpu --no-headers | head -n1 |
          awk '{ printf "%s (pid %s) is using %s%% CPU\n", $3, $1, $2 }'
      }
    '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  programs.opencode = {
    enable = true;
    settings = {
      # read-only tools never prompt; edits/fetch still ask
      permission = {
        read = "allow";
        list = "allow";
        glob = "allow";
        grep = "allow";
        edit = "ask";
        webfetch = "ask";
        # default-ask, with read-only shell commands allowed (last match wins)
        bash = {
          "*" = "ask";
          "ls *" = "allow";
          "cat *" = "allow";
          "head *" = "allow";
          "tail *" = "allow";
          "pwd" = "allow";
          "echo *" = "allow";
          "which *" = "allow";
          "grep *" = "allow";
          "rg *" = "allow";
          "fd *" = "allow";
          "find *" = "allow";
          "tree *" = "allow";
          "wc *" = "allow";
          "stat *" = "allow";
          "file *" = "allow";
          "git status" = "allow";
          "git log *" = "allow";
          "git diff *" = "allow";
          "git show *" = "allow";
          "git branch *" = "allow";
        };
      };
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };

  programs.starship = {
    enable = true;
    settings = {
      format="\${custom.dir_prod}\${custom.dir_normal}$git_branch$git_commit$git_state$git_metrics$git_status$golang$rust$aws$nix_shell$character";
      git_branch = {
        symbol = "";
        format = "[$symbol $branch(:$remote_branch)]($style) ";
        style = "bright-yellow";
      };
      # character = {
      #   format = "\\\$ ";
      # };
      git_metrics = {
        disabled = false;
      };
      directory.disabled = true;
      custom.dir_prod = {
        command = starshipDirCmd;
        when = "pwd | grep -qi prod";
        shell = starshipDirShell;
        style = "bold red";
        format = " [$output]($style) ";
      };
      custom.dir_normal = {
        command = starshipDirCmd;
        when = "pwd | grep -qiv prod";
        shell = starshipDirShell;
        style = "bold blue";
        format = " [$output]($style) ";
      };
      rust = {
        format = "[$symbol]($style) ";
        symbol = "󱘗";
      };
      golang = {
        format = "[$symbol]($style) ";
        symbol = "go";
      };
      nix_shell = {
        format = "($style) ";
      };
      aws = {disabled = true;};
    };
  };
}

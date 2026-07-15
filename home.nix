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
    inputs.nhost-be.packages.${pkgs.system}.nhost-code
    inputs.nhost-be.packages.${pkgs.system}.gha
    inputs.nhost.packages.${pkgs.system}.ghactivity

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

  programs.k9s = {
    enable = true;
    skins.kanagawa = ./k9s/skins/kanagawa.yaml;
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
          enableMouse = false;
          headless = false;
          logoless = false;
          crumbsless = false;
          splashless = false;
          reactive = false;
          noIcons = false;
          invert = false;
          defaultsToFullScreen = false;
          useFullGVRTitle = false;
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

  programs.kitty = {
    enable = true;
    themeFile = "kanagawa";
    font = {
      name = "Hack Nerd Font Mono";
      size = 10;
    };
    keybindings = {
      "ctrl+minus" = "change_font_size all -1.0";
      "ctrl+plus" = "change_font_size all +1.0";
      "ctrl+0" = "change_font_size all 0";
    };
  };

  programs.tmux = {
    enable = true;
    prefix = "C-Space";
    baseIndex = 1;
    keyMode = "vi";
    mouse = true;
    escapeTime = 0;
    historyLimit = 10000;
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
    ];
    extraConfig = ''
      # true color passthrough
      set -ag terminal-overrides ",xterm-kitty:RGB"

      # kanagawa status bar background
      set -g status-style "bg=#2a2a37,fg=#dcd7ba"

      # pane border same color as status bar background
      set -g pane-border-style "fg=#2a2a37"
      set -g pane-active-border-style "fg=#2a2a37"

      # vim-tmux-navigator steals C-l for pane navigation;
      # restore clear-screen under the prefix (C-Space C-l)
      bind C-l send-keys 'C-l'
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
      nsp = "nix-shell --command zsh -p ";
      l = "eza -l --icons --git --sort=Extension";
      v = "nvim";
      q = "exit";
      k = "kubectl";
      gst = "git status";
      lg = "lazygit";
    };
    initContent = "bindkey -v";
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

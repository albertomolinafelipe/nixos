{ inputs, config, pkgs, ... }:

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
    claude-code

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
    tree
    htop
    eza
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
      size = 11;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };
  
  xdg.configFile."hypr/hyprland.lua".source = ./hypr/hyprland.lua;
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
      size = 11;
    };
    keybindings = {
      "ctrl+minus" = "decrease_font_size";
      "ctrl+plus" = "increase_font_size";
      "ctrl+0" = "restore_font_size";
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
      gst = "git status";
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
      format="$directory$git_branch$git_commit$git_state$git_metrics$git_status$golang$rust$nix_shell$character";
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
      directory = {
        format = " [$path]($style) ";
        style = "bold blue";
        truncation_length = 2;
        truncate_to_repo = false;
        truncation_symbol="../";
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

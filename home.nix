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

    waybar
    bemenu

    # utilities
    flameshot

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

  programs.waybar.enable = true;
  xdg.configFile."waybar/config.jsonc".source = ./waybar/config.jsonc;
  xdg.configFile."waybar/style.css".source = ./waybar/style.css;

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
      l = "eza -l --icons --git --sort=Extension";
      v = "nvim";
      q = "exit";
    };
    initContent = "bindkey -v";
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
        format = "($style) ";
      };
      aws = {disabled = true;};
    };
  };
}

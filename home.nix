{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "alberto";
  home.homeDirectory = "/home/alberto";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.hello
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome.gnome-themes-extra;
    };
  };
  qt = {
    enable = true;
    platformTheme = {
      name = "adwaita";
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting = {
      enable = true;
    };

    shellAliases = {
      l = "eza -l --icons --git --sort=Extension";
      v = "nvim";
      q = "exit";
      cd = "z";
      vol = "amixer set Master";
      shell = "nix develop --command zsh";
      update = "sudo nixos-rebuild switch --flake ~/nixos/#nixos-config";
    };

    history = {
      size = 10000;
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.git = {
    enable = true;
    userName = "albertomolinfelipe";
    userEmail = "albmf@protonmail.com";
  };
  programs.starship.enable = true;
  programs.starship.settings = {
      format="$directory$git_branch$git_commit$git_state$git_metrics$git_status$kotlin$rust$nix_shell$character";
      git_branch = {
        symbol = "";
        format = "[$symbol $branch(:$remote_branch)]($style) ";
        style = "bright-yellow";
      };
      character = {
        success_symbol = "[❯](bold #dd8b4f)";
      };
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
      kotlin = {
        format = "[$symbol]($style) ";
        symbol = " ";
        style = "#3ddc84";
      };
      rust = {
        format = "[$symbol]($style) ";
        symbol = "󱘗";
      };
      nix_shell = {
        format = "($style) ";
      };
      aws = {disabled = true;};
  };
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        title = "alacritty";
        opacity = 0.85;
      };
      font = {
        normal.family = "HackNerdFont";
        size = 12.0;
      };
      colors = {
        primary = {
          background = "#181820"; # sumInk1
          foreground = "#DCD7BA"; # fujiWhite
        };
        normal = {
          black = "#16161D"; # sumiInk0
          red = "#C34043"; # autumnRed
          green = "#76946A"; # autumnGreen
          yellow = "#C0A36E"; # boatYellow2
          blue = "#7E9CD8"; # crystalBlue
          magenta = "#957FB8"; # oniViolet
          cyan = "#6A9589"; # waveAqua1
          white = "#C8C093"; # oldWhite
        };
        bright = {
          black = "#727169"; # fujiGray
          red = "#E82424"; # samuraiRed
          green = "#98BB6C"; # springGreen
          yellow = "#E6C384"; # carpYellow
          blue = "#7FB4CA"; # springBlue
          magenta = "#938AA9"; # springViolet1
          cyan = "#7AA89F"; # waveAquea2
          white = "#DCD7BA"; # fujiWhite
        };
      };
    };
  };
  programs.home-manager.enable = true;
}

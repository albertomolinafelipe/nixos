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

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting = {
      enable = true;
    };

    shellAliases = {
      ll = "ls -l";
      l = "eza -l --icons --git --sort=Extension";
      v = "nvim";
      q = "exit";
      cd = "z";
      update = "sudo nixos-rebuild switch --flake ~/nixos/#nixos-config";
    };

    history = {
      size = 10000;
    };
    initExtra = ''
      PROMPT='%F{#E6C384}[%F{#7FB4CA}%n%F{none}@%F{blue}nixos%F{none}: %F{#FFA066}%B%~%b%F{#E6C384}] %B>%b%F{none} '
    '';
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
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        dimensions = {
          columns = 80;
          lines = 24;
        };
      };
      colors = {
        primary = {
          background = "#181820"; # sumInk1
          foreground = "#DCD7BA"; # fujiWhite
        };
	normal = {
	  black   = "#16161D";  # sumiInk0
	  red     = "#C34043";  # autumnRed
	  green   = "#76946A";  # autumnGreen
	  yellow  = "#C0A36E";  # boatYellow2
	  blue    = "#7E9CD8";  # crystalBlue
	  magenta = "#957FB8";  # oniViolet
	  cyan    = "#6A9589";  # waveAqua1
	  white   = "#C8C093";  # oldWhite
	};
	bright = {
	  black   = "#727169";  # fujiGray
	  red     = "#E82424";  # samuraiRed
	  green   = "#98BB6C";  # springGreen
	  yellow  = "#E6C384";  # carpYellow
	  blue    = "#7FB4CA";  # springBlue
	  magenta = "#938AA9";  # springViolet1
	  cyan    = "#7AA89F";  # waveAquea2
	  white   = "#DCD7BA";  # fujiWhite
	};
      };
    };
  };
  programs.home-manager.enable = true;
}

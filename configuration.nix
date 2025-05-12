{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/slstatus.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = { alberto = import ./home.nix; };
  };

  services.quassel.enable = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.extraModulePackages = [ pkgs.linuxPackages.v4l2loopback ];

  networking.hostName = "nixos";
  services.udisks2.enable = true;
  # Enable networking
  networking.networkmanager.enable = true;
  services.ofono.enable = true;
  services.blueman.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  virtualisation.docker.enable = true;

  # Desktop
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;

    displayManager.sessionCommands = ''
      if xrandr | grep -q "DP-4 connected"; then
        xrandr --output DP-4 --auto --scale 1x1 --transform 1,0,0,0,1,0,0,0,1 --primary
        echo "Xft.dpi: 96" | xrdb -merge
        xrandr --output eDP-1 --off
      else
        xrandr --output eDP-1 --auto --scale 1x1 --transform 1,0,0,0,1,0,0,0,1 --primary
        # xrandr --output DP-4 --off
        echo "Xft.dpi: 192" | xrdb -merge
      fi
      feh --bg-fill ~/nixos/themes/nixos_pixel.png
      slstatus &
      picom &
      syncthing &
      dunst &
    '';
    desktopManager.gnome.enable = false;
    windowManager.dwm.enable = true;
  };

  nixpkgs.overlays = [
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (old: { src = ./configs/dwm; });
      neovim = prev.neovim.overrideAttrs (oldAttrs: rec {
        config = builtins.path { path = ./configs/nvim; };
      });
    })
  ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "es";
    variant = "";
  };

  console.keyMap = "es";
  services.printing.enable = true;

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  hardware.pulseaudio.enable = true;
  services.pipewire = {
    enable = false;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
    };
  };


  # User	
  users.users.alberto = {
    isNormalUser = true;
    description = "alberto";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [ ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;
  programs.steam.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.permittedInsecurePackages = [ "electron-25.9.0" ];

  fonts.packages = with pkgs.nerd-fonts; [
    hack
    gohufont
  ];

  services.slstatus.enable = true;
  services.cron.enable = true;
  services.ollama.enable = true;
  system.activationScripts = {
    script.text = ''
      install -d -m 755 /home/alberto/open-webui/data -o root -g root
    '';
   };
  environment.systemPackages = with pkgs; [
    # uc3m
    anki

    # Essentials
    gcc
    gnumake
    clang
    git
    bc
    ripgrep
    alsa-utils
    hsphfpd
    dunst 
    libnotify
    droidcam
    pulsemixer

    # Desktop
    home-manager
    alacritty
    neovim
    dwm
    dmenu

    # Personal
    firefox
    obsidian
    signal-desktop
    discord
    keepassxc
    calibre
    kdePackages.okular
    steam
    syncthing
    wirelesstools
    androidStudioPackages.dev

    # Development 
    rpcsvc-proto
    libtirpc
    zsh
    cargo
    rustc
    rust-analyzer
    terraform-ls
    python3
    pyright
    nodejs
    cjson
    nixpkgs-fmt
    hugo
    zip
    unzip
    texliveFull
    act
    protobuf
    openssl
    go

    # Terminal tools
    starship
    htop
    flameshot
    xclip
    eza
    zoxide
    tree
    feh
    picom
    neofetch
    tree-sitter
    pandoc
    usbutils
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

}

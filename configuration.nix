 
{ config, pkgs, inputs, ... }:
{
  imports = [
      ./hardware-configuration.nix
      ./modules/slstatus.nix
      inputs.home-manager.nixosModules.home-manager
    ];
  
  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    users = {alberto = import ./home.nix;};
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

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


  # Desktop
  services.xserver = {
    enable = true;
    dpi = 180;
    displayManager.gdm.enable = true;
    displayManager.sessionCommands = ''
      ${pkgs.feh}/bin/feh --bg-fill ./themes/nixos_dark.png
    '';
    desktopManager.gnome.enable = false;
    windowManager.dwm.enable = true;
  };

  nixpkgs.overlays = [
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (old: {src = ./configs/dwm;});
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
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # User	
  users.users.alberto = {
    isNormalUser = true;
    description = "alberto";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.permittedInsecurePackages = ["electron-25.9.0"];
  
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "Hack" "Gohu" ]; })
  ];

  services.slstatus.enable = true;
  environment.systemPackages = with pkgs; [
  	git
	neofetch
	wirelesstools
	alacritty
	neovim
	firefox
	obsidian
	dwm
	dmenu

	home-manager
	signal-desktop
	keepassxc
	tree
	zsh

	feh
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

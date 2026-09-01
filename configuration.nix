{ inputs, config, lib, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
      inputs.home-manager.nixosModules.home-manager
    ];
  
  home-manager = {
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit inputs; };
    users = { alberto = import ./home.nix; };
  };

  # Hardware
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-d7c2cbf4-97e3-4275-86be-d0715bba8399".device = "/dev/disk/by-uuid/d7c2cbf4-97e3-4275-86be-d0715bba8399";

  # The SOC2 firewall (networking.firewall.enable in secureframe.nix) defaults
  # the FORWARD chain to DROP. With br_netfilter loaded, kind's cross-node pod
  # traffic is bridged through that chain and silently dropped, which breaks
  # pod-to-pod networking and admission webhooks. Don't send bridged frames
  # through iptables so the firewall stays enabled without dropping them.
  boot.kernel.sysctl."net.bridge.bridge-nf-call-iptables" = 0;
  boot.kernel.sysctl."net.bridge.bridge-nf-call-ip6tables" = 0;
  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  nix.settings = {
    trusted-users = [ "root" "alberto" ];
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_ES.UTF-8";
    LC_IDENTIFICATION = "es_ES.UTF-8";
    LC_MEASUREMENT = "es_ES.UTF-8";
    LC_MONETARY = "es_ES.UTF-8";
    LC_NAME = "es_ES.UTF-8";
    LC_NUMERIC = "es_ES.UTF-8";
    LC_PAPER = "es_ES.UTF-8";
    LC_TELEPHONE = "es_ES.UTF-8";
    LC_TIME = "es_ES.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "es";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "es";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  programs.zsh.enable = true;
  programs.steam.enable = true;

  users.users."alberto" = {
    isNormalUser = true;
    description = "alberto";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [];
    shell = pkgs.zsh;
  };

  virtualisation.docker = {
    enable = true;
    # Use the classic overlay2 image store. Docker 29 defaults to the
    # containerd image store, whose streaming load path breaks skopeo's
    # `docker-daemon:` transport (used by `make build-docker-image`).
    daemon.settings.features.containerd-snapshotter = false;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Fonts
  fonts.packages = with pkgs.nerd-fonts; [
    hack
    gohufont
  ];

  # Some programs need SUID wrappers, can be configured further or are
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # command = "${pkgs.tuigreet}/bin/tuigreet --time --remember";
	command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --sessions /run/current-system/sw/share/wayland-sessions";
	user = "greeter";
      };
    };
  };
  services.blueman.enable = true;

  # Secureframe / Fleet compliance agent lives in ./secureframe.nix (imported
  # via the flake). It uses nixpkgs' declarative services.osquery + a mitmproxy
  # instead of the old imperative orbit agent, so no nix-ld shim is needed.

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "alberto";
    group = "users";
    dataDir = "/home/alberto/Sync";
  };

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
  system.stateVersion = "26.05"; # Did you read the comment?

}

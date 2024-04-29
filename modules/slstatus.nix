{ config, lib, pkgs, ... }:

{
  options = {
    services.slstatus.enable = lib.mkEnableOption "Custom slstatus";
  };

  config = lib.mkIf config.services.slstatus.enable {
    environment.systemPackages = [ (pkgs.slstatus.overrideAttrs (oldAttrs: {
      patches = oldAttrs.patches ++ [ ./configs/slstatus-config.patch ];
    })) ];
    services.xserver.displayManager.sessionCommands = ''
      # Start the customized slstatus
      ${pkgs.slstatus}/bin/slstatus &
    '';
  };
}


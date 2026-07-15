# SecureFrame

Results of reversing/annoying stuff to get SecureFrame to like NixOS, some
adaptation required depending on how your system configuration is setup, but
all the annoying work has been done already.

## `extract.py`

Run the extract.py script on the `.deb` you can download from SecureFrame after
onboarding is done, keep in mind these `.deb` files are unique per device and
this process has to be done for each.

I forgot what the output of this script is so it might need some fiddling, it's
supposed to output a nix expression for osquery.

## `proxy.py`

This is a MITM proxy to massage osquery to be compatible with SecureFrame's
bullshit. It also filters out queries they don't need to be making for SOC2
compliance in case they get nosy or who knows.

## configuration.nix

Bunch of configuration needed to actually be SOC2 compliant.

```nix
{ pkgs, lib, ... }:
{
  security.protectKernelImage = true;
  security.polkit.enable = true;
  security.nixsecauditor.enable = true;
  security.auditd.enable = false;
  security.audit.enable = false;
  security.audit.rules = [
    "-a always,exit -F arch=b64 -S open,openat,creat -F exit>=0 -k file_access"
    "-w /etc/ -p wa -k config_changes"
    "-w /home -p wa -k home_changes"
  ];

  # SOC2 wants an antivirus, this is not actually checked by SecureFrame but at
  # least we're compliant.
  services.clamav = {
    updater.enable = true;
    fangfrisch.enable = true;
    daemon.enable = true;
  };

  # SOC2 wants rate-limiting for login attempts.
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "maxlogins";
      value = "5";
    }
  ];

  # SOC2 wants limits on password quality, but they're cringe.
  security.pam.services.passwd.rules.password.pwquality = {
    order = 9000;
    control = "requisite";
    modulePath = "${pkgs.libpwquality.lib}/lib/security/pam_pwquality.so";
    args = [
      "retry=3"
      "minlen=8"
      "minclass=3"
    ];
  };

  # SOC2 wants firewall to be enabled, but then SecureFrame does not check how
  # the firewall is configured as long as it's enabled.
  networking.firewall.enable = true;

  services.osquery = {
    enable = true;
    flags = {
      extensions_autoload = "${pkgs.writeText "osquery-extensions.load" "${pkgs.fleetd-tables}/bin/fleetd_tables.ext"}";
      extensions_timeout = "10";
      allow_unsafe = "true";
      config_plugin = "tls";
      config_tls_endpoint = "/api/v1/osquery/config";
      config_tls_refresh = "10";
      disable_distributed = "false";
      distributed_plugin = "tls";
      distributed_tls_read_endpoint = "/api/v1/osquery/distributed/read";
      distributed_tls_write_endpoint = "/api/v1/osquery/distributed/write";
      enroll_tls_endpoint = "/api/v1/osquery/enroll";
      host_identifier = "specified";
      logger_plugin = "tls";
      logger_tls_endpoint = "/api/v1/osquery/log";
      logger_tls_period = "10";
      specified_identifier = "5458a3a0-f94a-43ca-9882-e4c1331b53e3:10db8ecb-30d0-4747-931a-0c40f59d6540:bbb7be3d-9ce9-4b8c-a9a8-dfbda8704f2a";
      tls_hostname = "127.0.0.1:4443";
      tls_server_certs = "/var/lib/osquery-proxy/mitmproxy-ca-cert.pem";
    };
  };

  # Need a running MITM proxy to make things actually work, especially enrollment
  # breaks completely without this.
  systemd.services.osquery-proxy = {
    description = "mitmproxy reverse proxy for osqueryd to Secureframe";
    wantedBy = [ "multi-user.target" ];
    before = [ "osqueryd.service" ];
    serviceConfig = {
      StateDirectory = "osquery-proxy";
      ExecStart = ''
        ${pkgs.mitmproxy}/bin/mitmdump \
          --set confdir=/var/lib/osquery-proxy \
          --mode reverse:https://agent-uk.secureframe.com:443 \
          --listen-port 4443 \
          --ssl-insecure \
          -s ${../../pkgs/secureframe.py}
      '';
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  systemd.services.osqueryd = {
    after = [ "osquery-proxy.service" ];
    requires = [ "osquery-proxy.service" ];
  };

  # Compatibility shims for Secureframe's Debian-only osquery checks.
  # The host is genuinely compliant (LUKS, nftables firewall, ClamAV); these
  # only translate the artifacts their queries inspect into the shape they
  # expect. See pkgs/secureframe.py for the corresponding os_version rewrite.
  systemd.services.ufw = {
    description = "no-op ufw shim for Secureframe firewall check";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/true";
      RemainAfterExit = true;
    };
  };

  # Not needed for SOC2 but doesn't hurt.
  environment.etc."npmrc".text = ''
    ignore-scripts=true
    min-release-age=7
  '';

  # PAM very unhappy without this.
  environment.etc."pam.d/common-password".text = ''
    password requisite pam_pwquality.so retry=3 minlen=8 minclass=3
    password [success=1 default=ignore] pam_unix.so obscure use_authtok try_first_pass yescrypt
    password requisite pam_deny.so
    password required pam_permit.so
  '';

  # Random bullshit to convince SecureFrame we're good guys™.
  systemd.tmpfiles.rules = [
    "d /var/osquery 0755 root root -"
    "d /var/lib/osquery 0755 root root -"
    "d /opt/osquery 0755 root root -"
    "d /opt/osquery/share 0755 root root -"
    "d /opt/osquery/share/osquery 0755 root root -"
    "L+ /opt/osquery/share/osquery/lenses - - - - ${pkgs.augeas}/share/augeas/lenses/dist"
    "d /var/lib/dpkg 0755 root root -"
    "L+ /var/lib/dpkg/status - - - - ${pkgs.writeText "secureframe-dpkg-status" ''
      Package: ufw
      Status: install ok installed
      Version: 0.36.2
      Architecture: amd64
      Maintainer: NixOS Compat <root@localhost>
      Description: shim for Secureframe firewall query
    ''}"
  ];

  # Please use sops for your secret management, if you don't I will cry.
  sops = {
    secrets.secureframe = {
      sopsFile = ./secrets/secureframe.yaml;
      format = "yaml";
      key = config.networking.hostName;
      restartUnits = [ "osquery-proxy.service" ];
    };
  };
}
```


# `home-manager.nix`

```nix
{ pkgs, lib, ... }:
{
  # Obviously if you aren't using Noctalia, change the settings for whatever
  # you use, SOC2 requires this.
  programs.noctalia = {
    settings = {
      # SOC2: 15-minute inactivity auto-lock and screen-off. Do not relax
      # without compliance review. Runtime edits in the Settings UI will
      # override these via state-dir settings.toml — keep declarative as
      # the floor.
      idle.behavior.lock = {
        enabled = true;
        timeout = 15 * 60;
        command = "noctalia:session lock";
      };
      idle.behavior."screen-off" = {
        enabled = true;
        timeout = 15 * 60;
        command = "noctalia:dpms-off";
        resume_command = "noctalia:dpms-on";
      };
    };
  };
}
```

## sops

The enrollment key is stored in a sops file with `<hostname>: <enrollment
key>`, this allows to keep multiple devices on secureframe without being
annoying. But this does mean you gotta setup sops-nix ;^)

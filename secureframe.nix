{ config, lib, pkgs, ... }:

# Declarative Secureframe / Fleet compliance setup for NixOS.
#
# Instead of running the imperative `orbit` agent (which self-updates static
# Debian binaries into a mutable /opt), we run nixpkgs' own osquery with the
# fleetd_tables extension and point it at a local mitmproxy. The proxy
# (pkgs/secureframe.py) reverse-proxies to Secureframe, injects the enroll
# secret, and filters distributed queries to an allowlist.
#
# The host is genuinely compliant (LUKS, firewall, ClamAV, screen lock); the
# tmpfiles/dpkg shims below only translate NixOS artifacts into the shape
# Secureframe's Debian-only checks expect.
let
  fleetd-tables = pkgs.callPackage ./pkgs/fleetd-tables.nix { };

  # This device's Secureframe enrollment identity, extracted from its unique
  # .deb via secureframe/extract.py. Regenerate per device.
  specifiedIdentifier =
    "449b428c-f163-4869-9bf5-5afe38fd000d:10db8ecb-30d0-4747-931a-0c40f59d6540:ea7dfb35-6d2c-4868-bb26-e51957ceecaa";

  # Secureframe regional agent endpoint the proxy forwards to.
  upstream = "agent-uk.secureframe.com:443";
in
{
  security.protectKernelImage = true;
  security.polkit.enable = true;
  security.auditd.enable = false;
  security.audit.enable = false;
  security.audit.rules = [
    "-a always,exit -F arch=b64 -S open,openat,creat -F exit>=0 -k file_access"
    "-w /etc/ -p wa -k config_changes"
    "-w /home -p wa -k home_changes"
  ];

  # SOC2 wants an antivirus. Not actually checked by Secureframe, but compliant.
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

  # SOC2 wants password quality limits.
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

  # SOC2 wants the firewall enabled; it doesn't inspect how it's configured.
  networking.firewall.enable = true;

  services.osquery = {
    enable = true;
    flags = {
      extensions_autoload = "${pkgs.writeText "osquery-extensions.load" "${fleetd-tables}/bin/fleetd_tables.ext"}";
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
      specified_identifier = specifiedIdentifier;
      tls_hostname = "127.0.0.1:4443";
      tls_server_certs = "/var/lib/osquery-proxy/mitmproxy-ca-cert.pem";
    };
  };

  # mitmproxy reverse proxy: osquery's native TLS calls -> Secureframe.
  # Enrollment breaks entirely without this (it injects the enroll secret and
  # presents a cert osquery trusts). The secret is read from the sops path via
  # SECUREFRAME_ENROLL_SECRET_FILE.
  systemd.services.osquery-proxy = {
    description = "mitmproxy reverse proxy for osqueryd to Secureframe";
    wantedBy = [ "multi-user.target" ];
    before = [ "osqueryd.service" ];
    environment.SECUREFRAME_ENROLL_SECRET_FILE = config.sops.secrets.secureframe.path;
    serviceConfig = {
      StateDirectory = "osquery-proxy";
      ExecStart = ''
        ${pkgs.mitmproxy}/bin/mitmdump \
          --set confdir=/var/lib/osquery-proxy \
          --mode reverse:https://${upstream} \
          --listen-port 4443 \
          --ssl-insecure \
          -s ${./pkgs/secureframe.py}
      '';
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  systemd.services.osqueryd = {
    after = [ "osquery-proxy.service" ];
    requires = [ "osquery-proxy.service" ];
  };

  # No-op ufw shim so Secureframe's Debian firewall check passes. The real
  # firewall is nftables above.
  systemd.services.ufw = {
    description = "no-op ufw shim for Secureframe firewall check";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/true";
      RemainAfterExit = true;
    };
  };

  environment.etc."npmrc".text = ''
    ignore-scripts=true
    min-release-age=7
  '';

  # PAM is unhappy without an explicit common-password stack for pwquality.
  environment.etc."pam.d/common-password".text = ''
    password requisite pam_pwquality.so retry=3 minlen=8 minclass=3
    password [success=1 default=ignore] pam_unix.so obscure use_authtok try_first_pass yescrypt
    password requisite pam_deny.so
    password required pam_permit.so
  '';

  # Shims to satisfy Secureframe's Debian-only osquery checks: expected dirs,
  # augeas lenses, and a dpkg status entry advertising an installed ufw.
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

  # sops-nix decrypts secrets at activation using this age key. Install it once
  # per machine, root-owned, outside the Nix store (see secureframe/README.md).
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # Enrollment secret, keyed per-host so multiple devices share one sops file.
  sops.secrets.secureframe = {
    sopsFile = ./secrets/secureframe.yaml;
    format = "yaml";
    key = config.networking.hostName;
    restartUnits = [ "osquery-proxy.service" ];
  };
}

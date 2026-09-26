# SecureFrame

Results of reversing/annoying stuff to get SecureFrame to like NixOS, some
adaptation required depending on how your system configuration is setup, but
all the annoying work has been done already.

In this repo the live version of all of this is `../secureframe.nix` (imported
by the flake) plus `../pkgs/`. The snippets below are the portable writeup —
if they ever disagree, the `.nix` files win.

## `extract.py`

Run the extract.py script on the `.deb` you can download from SecureFrame after
onboarding is done, keep in mind these `.deb` files are unique per device and
this process has to be done for each.

```sh
python3 extract.py path/to/secureframe-agent.deb
```

It unpacks the `ar`/`tar` layers, reads `etc/default/orbit` and the packaged
osquery flagfile, and prints a ready-to-paste `services.osquery = { ... };`
block on stdout. The value you actually care about is `specified_identifier`
(the `<device>:<org>:<enrollment>` triple) — that's the per-device identity.
The enroll secret (`ORBIT_ENROLL_SECRET`) goes into sops, not into the Nix
file. `--enroll` additionally tries to enroll straight against Fleet,
bypassing orbit; you normally don't need it since the proxy handles enrollment.

It also accepts an already-extracted directory instead of a `.deb`.

## `proxy.py`

This is a MITM proxy to massage osquery to be compatible with SecureFrame's
bullshit. It does three things:

- **Injects the enroll secret** into `/enroll` requests, read from the file in
  `$SECUREFRAME_ENROLL_SECRET_FILE` (default `/run/secrets/secureframe`).
  Enrollment breaks completely without this.
- **Spoofs `os_version`** to Ubuntu 24.04 on distributed/write results.
  Secureframe routes compliance scoring by `os_version.platform` and does not
  know what NixOS is. The underlying compliance (LUKS, firewall, ClamAV,
  screen lock) is genuine; only the distro identity is faked.
- **Filters distributed/read** against an allowlist of osquery tables, so they
  can't get nosy beyond what SOC2 actually needs.

Note: the copy the systemd unit runs is `../pkgs/secureframe.py`. The two files
are currently identical — if you change one, change the other (or delete this
one and keep a single source).

## `versions.toml`

Pins for `../pkgs/fleetd-tables.nix`, which builds Fleet's `fleetd_tables`
osquery extension (the `fleetd_*` tables Secureframe's distributed queries
reference). It is not in nixpkgs, hence the local derivation. Bump `rev`,
`srcHash` and `vendorHash` here — `versions.nix` just reads the TOML.

## configuration.nix

Bunch of configuration needed to actually be SOC2 compliant.

```nix
{ config, lib, pkgs, ... }:
let
  fleetd-tables = pkgs.callPackage ./pkgs/fleetd-tables.nix { };

  # Per-device, from extract.py. Regenerate for each machine.
  specifiedIdentifier =
    "449b428c-f163-4869-9bf5-5afe38fd000d:10db8ecb-30d0-4747-931a-0c40f59d6540:ea7dfb35-6d2c-4868-bb26-e51957ceecaa";

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

  # Need a running MITM proxy to make things actually work, especially enrollment
  # breaks completely without this. The enroll secret is handed to the script
  # by path, never through the store.
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
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets.secureframe = {
      sopsFile = ./secrets/secureframe.yaml;
      format = "yaml";
      key = config.networking.hostName;
      restartUnits = [ "osquery-proxy.service" ];
    };
  };
}
```

## `home-manager.nix`

SOC2 requires a 15-minute inactivity lock. Obviously if you aren't using
Hyprland, configure whatever idle daemon your setup has.

```nix
{ pkgs, lib, ... }:
{
  # SOC2: 15-minute inactivity auto-lock and screen-off. Do not relax the
  # timeouts without a compliance review.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 15 * 60;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 15 * 60;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  programs.hyprlock.enable = true;
}
```

## sops

The enrollment key is stored in a sops file with `<hostname>: <enrollment
key>`, this allows to keep multiple devices on secureframe without being
annoying. But this does mean you gotta setup sops-nix ;^)

The age key lives at `/var/lib/sops-nix/key.txt`, root-owned and outside the
Nix store. Install it once per machine before the first rebuild, otherwise
activation fails on decryption.

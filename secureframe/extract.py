#!/usr/bin/env python3
"""Parse a Secureframe .deb (or extracted dir) and print NixOS osquery config.

Usage: python secureframe.py [--enroll] <deb-file-or-extracted-dir>
"""

import argparse
import io
import json
import os
import platform
import re
import shutil
import ssl
import struct
import sys
import tarfile
import tempfile
import urllib.request


def parse_ar(data):
    """Yield (name, bytes) entries from an ar archive."""
    if not data.startswith(b"!<arch>\n"):
        raise ValueError("Not a valid .deb file")
    pos = 8
    while pos + 60 <= len(data):
        name = data[pos:pos+16].rstrip(b" /").decode()
        size = int(data[pos+48:pos+58].strip())
        pos += 60
        yield name, data[pos:pos+size]
        pos += size + (size % 2)


def extract_deb(path):
    tmpdir = tempfile.mkdtemp()
    with open(path, "rb") as f:
        ar_data = f.read()
    for name, payload in parse_ar(ar_data):
        if name.startswith("data.tar"):
            tar = tarfile.open(fileobj=io.BytesIO(payload))
            tar.extractall(tmpdir)
            tar.close()
            return tmpdir
    raise ValueError("data.tar not found in deb")


def parse_env_file(path):
    env = {}
    if not os.path.isfile(path):
        return env
    with open(path) as f:
        for line in f:
            line = re.sub(r"#.*$", "", line).strip()
            if "=" not in line:
                continue
            k, v = line.split("=", 1)
            v = v.strip().strip("'").rstrip("$").strip()
            if k.strip():
                env[k.strip().upper()] = v
    return env


def parse_unit_file(path):
    host_id = specified_id = None
    if not os.path.isfile(path):
        return host_id, specified_id
    with open(path) as f:
        for line in f:
            m = re.search(
                r"\s--\s+--host_identifier\s+(\S+)\s+--specified_identifier\s+(\S+)",
                line,
            )
            if m:
                host_id, specified_id = m.group(1), m.group(2)
                continue
            m = re.search(r"\s--\s+--specified_identifier\s+(\S+)", line)
            if m:
                specified_id = m.group(1)
            m = re.search(r"\s--\s+--host_identifier\s+(\S+)", line)
            if m:
                host_id = m.group(1)
    return host_id, specified_id


def parse_osquery_flags(path):
    flags = {}
    if not os.path.isfile(path):
        return flags
    with open(path, encoding="utf-8-sig") as f:
        content = f.read()
    for part in content.split("|"):
        part = part.strip()
        if not part:
            continue
        if "=" in part:
            k, v = part.split("=", 1)
        else:
            k, v = part, ""
        if k:
            flags[k] = v
    return flags


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("deb", help=".deb file or extracted directory")
    parser.add_argument(
        "--enroll",
        action="store_true",
        help="Attempt direct enrollment with Fleet server (bypass orbit)",
    )
    args = parser.parse_args()

    if not os.path.exists(args.deb):
        sys.exit(f"Path not found: {args.deb}")

    cleanup = False
    if os.path.isdir(args.deb):
        root = args.deb
    else:
        root = extract_deb(args.deb)
        cleanup = True

    try:
        _run(root, args.deb, args.enroll)
    finally:
        if cleanup:
            shutil.rmtree(root, ignore_errors=True)


def _run(root, deb_label, do_enroll):
    env = parse_env_file(os.path.join(root, "etc/default/orbit"))
    fleet_url = env.get("ORBIT_FLEET_URL")
    enroll_secret = env.get("ORBIT_ENROLL_SECRET")

    unit_host_id, unit_specified_id = parse_unit_file(
        os.path.join(root, "usr/lib/systemd/system/orbit.service")
    )

    flags = parse_osquery_flags(os.path.join(root, "opt/orbit/osquery.flags"))

    if fleet_url and "tls_hostname" not in flags:
        host = re.sub(r"^https?://", "", fleet_url)
        if not re.search(r":\d+$", host):
            host += ":443"
        defaults = {
            "disable_distributed": "true",
            "distributed_plugin": "tls",
            "logger_plugin": "tls",
            "logger_tls_endpoint": "/api/v1/osquery/results",
            "logger_tls_period": "10",
            "config_plugin": "tls",
            "config_tls_endpoint": "/api/v1/osquery/config",
            "config_tls_refresh": "10",
            "host_identifier": "uuid",
            "enroll_secret": enroll_secret or "",
            "enroll_tls_endpoint": "/api/v1/osquery/enroll",
            "tls_hostname": host,
            "tls_server_certs": "/etc/ssl/certs/ca-certificates.crt",
        }
        for k, v in defaults.items():
            flags.setdefault(k, v)

    if unit_host_id is not None and unit_specified_id is not None:
        flags["host_identifier"] = unit_host_id
        flags["specified_identifier"] = unit_specified_id

    certs_src = os.path.join(root, "opt/orbit/certs.pem")
    certs_nix = None
    if os.path.isfile(certs_src):
        certs_nix = os.path.join(root, "osquery-certs.pem")
        shutil.move(certs_src, certs_nix)

    # ---- Print Nix config ----
    print(f"# Generated from {deb_label}")
    print("services.osquery = {")
    print("  enable = true;")
    print("  flags = {")
    for k in sorted(flags):
        v = flags[k].replace("\\", "\\\\").replace('"', '\\"')
        print(f'    {k} = "{v}";')
    if certs_nix:
        print(f'    tls_server_certs = "{certs_nix}";')
    print("  };")
    print("};")

    osquery_bin = os.path.join(root, "opt/orbit/bin/osqueryd/linux/stable/osqueryd")
    if os.path.isfile(osquery_bin):
        print(f'# osqueryd_binary = "{osquery_bin}"')
    if certs_nix:
        print(f'# certs = "{certs_nix}"')

    # ---- Enroll directly with Fleet (bypass orbit) ----
    if do_enroll:
        tls_host = flags.get("tls_hostname")
        secret = flags.get("enroll_secret") or enroll_secret
        endpoint = flags.get("enroll_tls_endpoint", "/api/v1/osquery/enroll")
        host_id = flags.get("specified_identifier", "")

        if not tls_host:
            sys.exit("No tls_hostname found, cannot enroll")
        if not secret:
            sys.exit("No enroll_secret found, cannot enroll")

        url = f"https://{tls_host}{endpoint}".replace(":443", "", 1)

        hw_uuid = ""
        try:
            with open("/sys/class/dmi/id/product_uuid") as f:
                hw_uuid = f.read().strip()
        except OSError:
            pass

        body = json.dumps({
            "enroll_secret": secret,
            "host_identifier": host_id,
            "host_details": {
                "system_info": {
                    "hostname": platform.node(),
                    "uuid": hw_uuid,
                },
            },
        }).encode()

        ctx = ssl.create_default_context()
        if certs_nix and os.path.isfile(certs_nix):
            ctx.load_verify_locations(certs_nix)
        elif os.path.isfile("/etc/ssl/certs/ca-certificates.crt"):
            ctx.load_verify_locations("/etc/ssl/certs/ca-certificates.crt")

        print(f"Enrolling with {url} ...", file=sys.stderr)
        if host_id:
            print(f"host_identifier: {host_id}", file=sys.stderr)

        req = urllib.request.Request(
            url, data=body,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "osqueryd/5.0",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, context=ctx) as resp:
                result = json.loads(resp.read())
        except urllib.error.HTTPError as e:
            print(f"Enrollment failed: {e.code} {e.reason}", file=sys.stderr)
            print(f"Body: {e.read().decode()}", file=sys.stderr)
            sys.exit(1)
        except urllib.error.URLError as e:
            sys.exit(f"Enrollment failed: {e.reason}")

        if result.get("node_key"):
            print(f"\n# === Enrollment successful ===")
            print(f"# node_key = {result['node_key']}")
            print(f"Got node_key: {result['node_key']}", file=sys.stderr)
        elif result.get("node_invalid"):
            print("Server rejected enrollment (node_invalid=true)", file=sys.stderr)
            print(f"Response: {json.dumps(result)}", file=sys.stderr)
            sys.exit(1)
        else:
            print(f"Unexpected response: {json.dumps(result)}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()

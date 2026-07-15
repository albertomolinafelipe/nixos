"""mitmproxy addon for proxying osqueryd to Secureframe.

Rewrites requests so osqueryd's native TLS calls pass Cloudflare
and Fleet's enrollment endpoint. Provides hooks for filtering
data sent to Secureframe.

Usage:
  mitmdump --mode reverse:https://agent-uk.secureframe.com:443 \
    --listen-port 4443 --ssl-insecure -s secureframe.py
"""

import json
import os
import re
import sys

from mitmproxy import http

ENROLL_SECRET_FILE = os.environ.get(
    "SECUREFRAME_ENROLL_SECRET_FILE",
    "/run/secrets/secureframe",
)
try:
    with open(ENROLL_SECRET_FILE) as _f:
        ENROLL_SECRET = _f.read().strip()
except FileNotFoundError:
    ENROLL_SECRET = ""

# Secureframe routes compliance scoring by os_version.platform and won't
# support NixOS. Rewrite outgoing distributed/write results to claim Ubuntu
# so the host is classified as a known Linux distro. Underlying compliance
# (LUKS, firewall, ClamAV, ...) is genuine; only the distro identity is faked.
UBUNTU_OS_FIELDS = {
    "name": "Ubuntu",
    "version": "24.04 (Noble Numbat)",
    "major": "24",
    "minor": "4",
    "patch": "0",
    "build": "",
    "extra": "",
    "platform": "ubuntu",
    "platform_like": "debian",
    "codename": "noble",
}
OS_QUERIES = ("fleet_detail_query_os_version", "fleet_detail_query_os_unix_like")
UBUNTU_LABEL = "fleet_label_query_8"
DISK_ENC_QUERY = "fleet_detail_query_disk_encryption_linux"

# Allowlist of osquery tables Secureframe is permitted to query. Any
# distributed/read query whose SQL touches a table outside this set is
# stripped before osqueryd runs it, and any matching write result is dropped
# as a backstop. Update consciously when Secureframe adds new compliance
# checks; drop logs surface offenders.
ALLOWED_TABLES = frozenset(
    {
        "alf",
        "augeas",
        "bitlocker_info",
        "deb_packages",
        "disk_encryption",
        "gatekeeper",
        "google_chrome_profiles",
        "interface_addresses",
        "interface_details",
        "kernel_info",
        "kubernetes_info",
        "logged_in_users",
        "managed_policies",
        "mounts",
        "orbit_info",
        "os_version",
        "osquery_flags",
        "osquery_info",
        "osquery_registry",
        "osquery_schedule",
        "registry",
        "routes",
        "rpm_packages",
        "security_profile_info",
        "system_info",
        "systemd_units",
        "uptime",
        "windows_security_center",
        "windows_security_products",
    }
)
_TABLE_RE = re.compile(r"\b(?:from|join)\s+([a-zA-Z_][a-zA-Z0-9_]*)", re.IGNORECASE)
_CTE_RE = re.compile(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\s+as\s*\(", re.IGNORECASE)
_APPROVED: set[str] = set()


def _query_tables(sql: str) -> set[str]:
    ctes = {m.group(1).lower() for m in _CTE_RE.finditer(sql)}
    tables = {m.group(1).lower() for m in _TABLE_RE.finditer(sql)}
    return tables - ctes


def _filter_distributed_read(body):
    queries = body.get("queries")
    if not isinstance(queries, dict):
        return
    discovery = body.get("discovery") if isinstance(body.get("discovery"), dict) else {}
    approved = set()
    for name, sql in list(queries.items()):
        if not isinstance(sql, str):
            continue
        bad = _query_tables(sql) - ALLOWED_TABLES
        if bad:
            print(
                f"!!! dropping query {name}: references {sorted(bad)}",
                file=sys.stderr,
                flush=True,
            )
            del queries[name]
            discovery.pop(name, None)
        else:
            approved.add(name)
    _APPROVED.clear()
    _APPROVED.update(approved)


def _spoof_distributed_write(body):
    queries = body.get("queries")
    if not isinstance(queries, dict):
        return
    if _APPROVED:
        for name in list(queries):
            if name not in _APPROVED:
                print(
                    f"!!! dropping result {name}: not on allowlist",
                    file=sys.stderr,
                    flush=True,
                )
                del queries[name]
                if isinstance(body.get("statuses"), dict):
                    body["statuses"].pop(name, None)
                if isinstance(body.get("messages"), dict):
                    body["messages"].pop(name, None)
                if isinstance(body.get("stats"), dict):
                    body["stats"].pop(name, None)
    # for name in OS_QUERIES:
    #    rows = queries.get(name)
    #    if isinstance(rows, list):
    #        queries[name] = [{**r, **UBUNTU_OS_FIELDS} for r in rows]
    # if isinstance(queries.get(UBUNTU_LABEL), list):
    #    queries[UBUNTU_LABEL] = [{"1": "1"}]
    rows = queries.get(DISK_ENC_QUERY)
    if isinstance(rows, list):
        queries[DISK_ENC_QUERY] = [r for r in rows if r.get("path") == "/"]


def request(flow: http.HTTPFlow):
    flow.request.headers["User-Agent"] = "osqueryd/5.0"
    flow.request.headers["Host"] = "agent-uk.secureframe.com"

    if flow.request.path.endswith("/enroll") and ENROLL_SECRET:
        try:
            body = json.loads(flow.request.content)
        except (json.JSONDecodeError, TypeError):
            return
        if not body.get("enroll_secret"):
            body["enroll_secret"] = ENROLL_SECRET
        flow.request.content = json.dumps(body).encode()

    if flow.request.path.endswith("/distributed/write"):
        try:
            body = json.loads(flow.request.content)
        except (json.JSONDecodeError, TypeError):
            body = None
        if isinstance(body, dict):
            _spoof_distributed_write(body)
            flow.request.content = json.dumps(body).encode()

    body = flow.request.content.decode(errors="replace") if flow.request.content else ""
    print(
        f">>> {flow.request.method} {flow.request.path} {body}",
        file=sys.stderr,
        flush=True,
    )


def response(flow: http.HTTPFlow):
    if flow.request.path.endswith("/distributed/read"):
        try:
            body = json.loads(flow.response.content)
        except (json.JSONDecodeError, TypeError):
            body = None
        if isinstance(body, dict):
            _filter_distributed_read(body)
            flow.response.content = json.dumps(body).encode()

    body = (
        flow.response.content.decode(errors="replace") if flow.response.content else ""
    )
    print(
        f"<<< {flow.response.status_code} {flow.request.path} {body}",
        file=sys.stderr,
        flush=True,
    )

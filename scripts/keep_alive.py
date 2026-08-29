#!/usr/bin/env python3
"""
Qataly Backend Keep-Alive
يشتغل كـ cron job على الجهاز — يـ restore الـ Supabase كل 3 أيام
"""

import urllib.request
import urllib.error
import json
import time
import sys
from datetime import datetime, timezone

# ─── Config ───────────────────────────────────────────────
PROJECT_REF      = "qbnzxhiuoxfnxdbpozrx"
ACCESS_TOKEN     = "sbp_2ba4b5acdd2ddb8b742cd49c49577b6f899c26b6"
SUPABASE_URL     = "https://qbnzxhiuoxfnxdbpozrx.supabase.co"
ANON_KEY         = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibnp4aGl1b3hmbnhkYnBvenJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxMjc2MzEsImV4cCI6MjEwMjcwMzYzMX0"
    ".4329lT-YSjE6fuq7maldgDEP7YLShxbd5UNxnpQ3WQg"
)
MGMT_BASE        = "https://api.supabase.com/v1"
# ──────────────────────────────────────────────────────────


def log(msg: str):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    print(f"[{ts}] {msg}", flush=True)


UA = "QatalyKeepAlive/1.0"


def api_get(url: str, headers: dict) -> dict:
    headers = {**headers, "User-Agent": UA}
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def api_post(url: str, headers: dict, data: bytes = b"{}") -> int:
    headers = {**headers, "User-Agent": UA}
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def http_get_status(url: str, headers: dict) -> int:
    headers = {**headers, "User-Agent": UA}
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0


def get_project_status() -> str:
    headers = {"Authorization": f"Bearer {ACCESS_TOKEN}"}
    data = api_get(f"{MGMT_BASE}/projects/{PROJECT_REF}", headers)
    return data.get("status", "UNKNOWN")


def restore_project() -> bool:
    log("⚠️  Project inactive — sending restore request...")
    headers = {
        "Authorization": f"Bearer {ACCESS_TOKEN}",
        "Content-Type": "application/json",
    }
    code = api_post(f"{MGMT_BASE}/projects/{PROJECT_REF}/restore", headers)
    log(f"   Restore response: HTTP {code}")

    log("   ⏳ Waiting 3 minutes for project to come up...")
    time.sleep(180)

    new_status = get_project_status()
    log(f"   Status after restore: {new_status}")
    return new_status in ("ACTIVE_HEALTHY", "COMING_UP")


def ping_rest_api() -> bool:
    url = f"{SUPABASE_URL}/rest/v1/profiles?select=id&limit=1"
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {ANON_KEY}",
    }
    code = http_get_status(url, headers)
    ok = code in (200, 401, 403)
    log(f"{'✅' if ok else '❌'} REST API → HTTP {code}")
    return ok


def ping_edge_functions():
    fns = ["telegram-login", "telegram-callback"]
    for fn in fns:
        url = f"{SUPABASE_URL}/functions/v1/{fn}"
        code = http_get_status(url, {})
        log(f"{'✅' if code in (200, 204) else '⚠️ '} Edge fn [{fn}] → HTTP {code}")


def run():
    log("═══ Qataly Keep-Alive ════════════════════════")

    # 1. Check status
    status = get_project_status()
    log(f"📊 Project status: {status}")

    # 2. Restore if needed
    if status != "ACTIVE_HEALTHY":
        ok = restore_project()
        if not ok:
            log("❌ Restore failed! Exiting.")
            sys.exit(1)
    else:
        log("✅ Project is healthy — no restore needed")

    # 3. Ping REST API
    ping_rest_api()

    # 4. Ping Edge Functions
    ping_edge_functions()

    log("═══ Done ═════════════════════════════════════")


if __name__ == "__main__":
    run()

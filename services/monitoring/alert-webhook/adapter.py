#!/usr/bin/env python3
"""Turn an Alertmanager webhook into a WhatsApp and a Telegram message.

Alertmanager ships native telegram_configs, but it has no way to template the
body of a webhook, and the lab's WhatsApp transport is the Evolution API, which
wants {"number":..,"text":..} with an apikey header. Doing both here keeps the
credentials in one env file instead of inside alertmanager.yml, and leaves
/usr/local/sbin/lab-notify.sh -- the transport the backup scripts depend on --
untouched.

Stdlib only on purpose: this runs on a plain python image with no build step, so
a broken dependency can never be the reason an alert fails to arrive.
"""

import json
import os
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

EVOLUTION_URL = os.environ.get("EVOLUTION_URL", "")
EVOLUTION_API_KEY = os.environ.get("EVOLUTION_API_KEY", "")
ALERT_WHATSAPP_TO = os.environ.get("ALERT_WHATSAPP_TO", "")
TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "")
PORT = int(os.environ.get("PORT", "9099"))
TIMEOUT = 20


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def post_json(url, payload, headers):
    data = json.dumps(payload).encode()
    headers = dict(headers)
    headers.setdefault("Content-Type", "application/json")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.status
    except urllib.error.HTTPError as exc:
        return exc.code
    except Exception as exc:  # DNS, TLS, timeout -- never crash the listener
        log("transport error for", url.split("/")[2], "--", exc)
        return 0


def render(body):
    """One line per alert, so a group of three still fits on a phone screen."""
    lines = []
    for alert in body.get("alerts", []):
        labels = alert.get("labels", {})
        annotations = alert.get("annotations", {})
        status = alert.get("status", body.get("status", "firing")).upper()
        name = labels.get("alertname", "alert")
        severity = labels.get("severity", "")
        detail = annotations.get("summary") or labels.get("instance", "")
        head = name if not severity else "{} ({})".format(name, severity)
        lines.append("[{}] {}: {}".format(status, head, detail))
    if not lines:
        return None
    return "lab alert\n" + "\n".join(lines)


def send(text):
    sent = []
    if EVOLUTION_URL and EVOLUTION_API_KEY and ALERT_WHATSAPP_TO:
        code = post_json(
            EVOLUTION_URL,
            {"number": ALERT_WHATSAPP_TO, "text": text},
            {"apikey": EVOLUTION_API_KEY},
        )
        sent.append("whatsapp={}".format(code))
    if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID:
        code = post_json(
            "https://api.telegram.org/bot{}/sendMessage".format(TELEGRAM_BOT_TOKEN),
            {"chat_id": TELEGRAM_CHAT_ID, "text": text, "disable_web_page_preview": True},
            {},
        )
        sent.append("telegram={}".format(code))
    if not sent:
        log("no transport configured -- alert dropped")
    return sent


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Gatus and docker both want something cheap to poll
        body = b"ok\n" if self.path == "/healthz" else b"alert-webhook\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode() or "{}")
        except ValueError:
            self.send_response(400)
            self.end_headers()
            return
        text = render(payload)
        # Always 200: Alertmanager retries on failure, and a retry storm would
        # cost more messages than the one that was lost
        self.send_response(200)
        self.end_headers()
        if text:
            log("alert ->", " ".join(send(text)))

    def log_message(self, *args):
        pass  # the useful line is printed in do_POST


if __name__ == "__main__":
    log("alert-webhook listening on :{}".format(PORT))
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()

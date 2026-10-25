"""Demo web app for Session 3: it exposes Prometheus metrics so you can practise observability.

No third-party packages. Endpoints
  /          -> JSON with the pod name
  /healthz   -> liveness / readiness probe target (not counted in the metrics)
  /work      -> pretends to do work; latency varies a little
  /flaky     -> fails with HTTP 500 for a share of calls (default 30 percent): /flaky?rate=0.5
  /metrics   -> Prometheus text format
"""
import json
import os
import random
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

POD = os.getenv("POD_NAME", "unknown")
BUCKETS = [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5]

_lock = threading.Lock()
_requests = {}              # (path, code) -> count
_hist_counts = [0] * (len(BUCKETS) + 1)   # last slot is +Inf
_hist_sum = 0.0
_hist_total = 0


def record(path: str, code: int, seconds: float) -> None:
    global _hist_sum, _hist_total
    with _lock:
        _requests[(path, str(code))] = _requests.get((path, str(code)), 0) + 1
        _hist_sum += seconds
        _hist_total += 1
        for i, upper in enumerate(BUCKETS):
            if seconds <= upper:
                _hist_counts[i] += 1
        _hist_counts[-1] += 1


def render_metrics() -> str:
    lines = [
        "# HELP demo_http_requests_total Requests handled, by path and status code.",
        "# TYPE demo_http_requests_total counter",
    ]
    with _lock:
        for (path, code), n in sorted(_requests.items()):
            lines.append(f'demo_http_requests_total{{path="{path}",code="{code}"}} {n}')
        lines += [
            "# HELP demo_http_request_duration_seconds Request latency.",
            "# TYPE demo_http_request_duration_seconds histogram",
        ]
        for i, upper in enumerate(BUCKETS):
            lines.append(f'demo_http_request_duration_seconds_bucket{{le="{upper}"}} {_hist_counts[i]}')
        lines.append(f'demo_http_request_duration_seconds_bucket{{le="+Inf"}} {_hist_counts[-1]}')
        lines.append(f"demo_http_request_duration_seconds_sum {_hist_sum:.6f}")
        lines.append(f"demo_http_request_duration_seconds_count {_hist_total}")
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: str, ctype: str = "application/json") -> None:
        payload = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):  # noqa: N802
        started = time.perf_counter()
        url = urlparse(self.path)
        path = url.path
        if path == "/healthz":
            self._send(200, json.dumps({"status": "ok"}))
            return
        if path == "/metrics":
            self._send(200, render_metrics(), "text/plain; version=0.0.4")
            return

        code, body = 200, {"app": "aks-ops-demo", "pod": POD}
        if path == "/work":
            time.sleep(random.uniform(0.005, 0.12))
            body["did"] = "work"
        elif path == "/flaky":
            try:
                rate = float(parse_qs(url.query).get("rate", ["0.3"])[0])
            except ValueError:
                rate = 0.3
            time.sleep(random.uniform(0.005, 0.05))
            if random.random() < rate:
                code, body = 500, {"error": "injected failure", "pod": POD}
        elif path != "/":
            code, body = 404, {"error": "not found"}
            path = "other"   # keep the label set small
        self._send(code, json.dumps(body))
        record(path, code, time.perf_counter() - started)

    def log_message(self, fmt, *args):  # quiet access log
        pass


if __name__ == "__main__":
    print(f"listening on :8080 as pod {POD}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()

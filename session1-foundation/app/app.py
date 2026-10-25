"""Tiny demo web app for Session 1.

Endpoints
  /          -> JSON with pod name and node name (watch these change as you scale)
  /healthz   -> liveness / readiness probe target
  /load      -> burns CPU for ~200 ms so you can trigger autoscaling
"""
import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

POD = os.getenv("POD_NAME", "unknown")
NODE = os.getenv("NODE_NAME", "unknown")


def burn_cpu(seconds: float) -> None:
    end = time.perf_counter() + seconds
    while time.perf_counter() < end:
        sum(i * i for i in range(2000))


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: dict) -> None:
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):  # noqa: N802
        if self.path == "/healthz":
            self._send(200, {"status": "ok"})
        elif self.path == "/load":
            burn_cpu(0.2)
            self._send(200, {"pod": POD, "node": NODE, "burned": "200ms"})
        else:
            self._send(200, {"app": "aks-demo", "pod": POD, "node": NODE})

    def log_message(self, *args):  # keep pod logs quiet under load
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()

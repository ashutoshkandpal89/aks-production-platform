"""Demo app for Session 2: reads a secret from Azure Key Vault with NO stored credentials.

How it authenticates
  The workload identity webhook injects AZURE_CLIENT_ID, AZURE_TENANT_ID and
  AZURE_FEDERATED_TOKEN_FILE into the pod. DefaultAzureCredential notices them and exchanges
  the pod's ServiceAccount token for an Entra ID token. There is no password, key or
  connection string anywhere in the image, the manifest, or the environment.

Endpoints
  /healthz  -> probe target (does not touch Key Vault)
  /secret   -> reads the secret from Key Vault and shows a masked preview
  /env      -> lists the AZURE_* environment variable NAMES, so you can see there is no secret
"""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

VAULT_URL = os.getenv("KEY_VAULT_URL", "")
SECRET_NAME = os.getenv("SECRET_NAME", "demo-secret")

_client = None


def client() -> SecretClient:
    global _client
    if _client is None:
        _client = SecretClient(vault_url=VAULT_URL, credential=DefaultAzureCredential())
    return _client


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: dict) -> None:
        payload = json.dumps(body, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):  # noqa: N802
        if self.path == "/healthz":
            self._send(200, {"status": "ok"})
        elif self.path == "/env":
            names = sorted(k for k in os.environ if k.startswith("AZURE_"))
            self._send(200, {
                "azure_env_var_names": names,
                "has_client_secret": "AZURE_CLIENT_SECRET" in os.environ,
                "uses_federated_token": "AZURE_FEDERATED_TOKEN_FILE" in os.environ,
            })
        elif self.path == "/secret":
            if not VAULT_URL:
                self._send(500, {"error": "KEY_VAULT_URL is not set"})
                return
            try:
                value = client().get_secret(SECRET_NAME).value or ""
                self._send(200, {
                    "vault": VAULT_URL,
                    "secret_name": SECRET_NAME,
                    "length": len(value),
                    "preview": value[:4] + "..." if value else "",
                    "authenticated_with": "workload identity (no stored secret)",
                })
            except Exception as exc:  # report the class only, never a stack trace
                self._send(500, {"error": type(exc).__name__, "hint": "check the role assignment and federated credential"})
        else:
            self._send(404, {"error": "not found"})

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()

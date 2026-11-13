#!/usr/bin/env python3
"""Serve the exported Godot Web build for LOCAL / LAN use only.

No dependencies, no service install, no daemon: run it when you need it,
stop with Ctrl+C. It is deliberately NOT a public deployment tool.

Usage:
  python tools/serve_web.py                          # localhost only, no auth
  python tools/serve_web.py --host 0.0.0.0 --port 8080   # LAN, requires password
  HOOK3D_WEB_PASSWORD=... python tools/serve_web.py --host 0.0.0.0

Binding to a non-loopback address without a password is refused on purpose.
The Web build lives in build/web (or unzip the private Release asset there).
"""
import argparse
import base64
import functools
import hmac
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

LOOPBACK = ("127.0.0.1", "localhost", "::1")


class Handler(SimpleHTTPRequestHandler):
    # Godot Web needs application/wasm for instantiateStreaming to work.
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "application/javascript",
        ".json": "application/json",
        ".html": "text/html; charset=utf-8",
    }

    def __init__(self, *args, auth=None, **kwargs):
        self.auth = auth
        super().__init__(*args, **kwargs)

    def _authorized(self):
        if not self.auth:
            return True
        header = self.headers.get("Authorization", "")
        supplied = ""
        if header.startswith("Basic "):
            try:
                supplied = base64.b64decode(header[6:]).decode("utf-8")
            except Exception:
                supplied = ""
        if hmac.compare_digest(supplied, self.auth):
            return True
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="hook3d internal"')
        self.send_header("Content-Length", "0")
        self.end_headers()
        return False

    def do_GET(self):
        if self._authorized():
            super().do_GET()

    def do_HEAD(self):
        if self._authorized():
            super().do_HEAD()

    def log_message(self, fmt, *args):
        sys.stderr.write("[serve_web] %s - %s\n" % (self.address_string(), fmt % args))


def main():
    parser = argparse.ArgumentParser(description="Local/LAN preview server for the internal Web build")
    parser.add_argument("--dir", default="build/web", help="directory containing index.html")
    parser.add_argument("--host", default="127.0.0.1", help="127.0.0.1 (default) or 0.0.0.0 for LAN")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--user", default="hook3d", help="Basic Auth username")
    parser.add_argument("--password", default=None, help="prefer HOOK3D_WEB_PASSWORD env var")
    args = parser.parse_args()

    web_dir = os.path.abspath(args.dir)
    if not os.path.isfile(os.path.join(web_dir, "index.html")):
        parser.error("no index.html in %s - export the Web build or unzip the private Release asset" % web_dir)

    password = args.password or os.environ.get("HOOK3D_WEB_PASSWORD")
    if args.host not in LOOPBACK and not password:
        parser.error("LAN binding requires HOOK3D_WEB_PASSWORD (or --password); refusing an open port")
    auth = "%s:%s" % (args.user, password) if password else None

    handler = functools.partial(Handler, directory=web_dir, auth=auth)
    server = ThreadingHTTPServer((args.host, args.port), handler)
    print("Serving %s at http://%s:%d/" % (web_dir, args.host, args.port))
    print("Mode: %s" % ("Basic Auth (user=%s, password from env)" % args.user if auth else "loopback only, no auth"))
    print("INTERNAL ONLY - do not port-forward or expose publicly. Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

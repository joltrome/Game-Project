#!/usr/bin/env python3
"""Serve a Godot Web export over HTTPS for trusted local-device testing."""

from __future__ import annotations

import argparse
import functools
import http.server
import ssl
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8170)
    args = parser.parse_args()

    directory = Path(args.directory).expanduser().resolve(strict=True)
    cert = Path(args.cert).expanduser().resolve(strict=True)
    key = Path(args.key).expanduser().resolve(strict=True)
    handler = functools.partial(
        http.server.SimpleHTTPRequestHandler,
        directory=str(directory),
    )
    server = http.server.ThreadingHTTPServer((args.bind, args.port), handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile=str(cert), keyfile=str(key))
    server.socket = context.wrap_socket(server.socket, server_side=True)
    print(f"Serving {directory} at https://{args.bind}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

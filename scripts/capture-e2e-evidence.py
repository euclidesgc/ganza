#!/usr/bin/env python3

import argparse
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            if self.path == '/health':
                self.send_response(204)
                self.end_headers()
                return

            name = self.path.removeprefix('/')
            if not re.fullmatch(r'[a-z0-9_]+', name):
                self.send_error(400, 'nome de evidência inválido')
                return

            capture = subprocess.run(
                ['adb', '-s', args.serial, 'exec-out', 'screencap', '-p'],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            if capture.returncode != 0 or not capture.stdout:
                self.send_error(500, capture.stderr.decode(errors='replace'))
                return

            (args.destination / f'{name}.png').write_bytes(capture.stdout)
            self.send_response(204)
            self.end_headers()

        def log_message(self, _format: str, *_args: object) -> None:
            return

    ThreadingHTTPServer(('0.0.0.0', args.port), Handler).serve_forever()


if __name__ == '__main__':
    main()

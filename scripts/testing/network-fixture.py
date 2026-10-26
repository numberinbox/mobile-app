#!/usr/bin/env python3
"""Loopback-only HTTP/WebSocket fixture for opt-in browser network tests.

Prints its ephemeral port. Contains no backend configuration or credentials.
"""
import base64
import hashlib
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def do_GET(self):
        if self.path.startswith('/socket'):
            if self.path != '/socket?ticket=synthetic-ticket':
                self.send_error(403)
                return
            key = self.headers.get('Sec-WebSocket-Key', '')
            digest = hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()
            self.send_response(101)
            self.send_header('Upgrade', 'websocket')
            self.send_header('Connection', 'Upgrade')
            self.send_header('Sec-WebSocket-Accept', base64.b64encode(digest).decode())
            self.send_header('Sec-WebSocket-Protocol', 'jmap')
            self.end_headers()
            time.sleep(1)
            self.wfile.write(b'\x88\x00')
            self.wfile.flush()
            self.close_connection = True
            return
        self.send_response(200 if self.path == '/healthy' else 404)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Type', 'text/plain')
        self.send_header('Content-Length', '2')
        self.end_headers()
        self.wfile.write(b'ok')

    def log_message(self, *_args):
        pass


if __name__ == '__main__':
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    print(server.server_port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

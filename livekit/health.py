import http.server
import socketserver
import os

PORT = int(os.environ.get("PORT", "8080"))

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        self.wfile.write(b"OK")

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Health server listening on port {PORT}")
    httpd.serve_forever()

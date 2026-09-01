import http.server
import socketserver
import logging
from api.auth import handler as AuthHandler

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

PORT = 8000


class RouterHandler(http.server.BaseHTTPRequestHandler):
    def _route(self, method):
        if self.path.startswith("/api/auth") or self.path.startswith("/auth") or self.path == "/":
            AuthHandler(self.request, self.client_address, self.server)
        elif self.path.startswith("/api/cron") or self.path.startswith("/cron"):
            from api.cron import handler as CronHandler
            CronHandler(self.request, self.client_address, self.server)
        else:

            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"error": "Not Found"}')

    def do_GET(self):
        self._route("GET")

    def do_POST(self):
        self._route("POST")

    def do_OPTIONS(self):
        self._route("OPTIONS")


if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), RouterHandler) as httpd:
        logger.info(f"Local AI News Aggregator Server running at http://localhost:{PORT}")
        logger.info(f" - Auth endpoint: http://localhost:{PORT}/api/auth")
        logger.info(f" - Cron pipeline endpoint: http://localhost:{PORT}/api/cron")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            logger.info("Server stopped.")

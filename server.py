import http.server
import socketserver
import logging
from api.auth import handler as AuthHandler

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

PORT = 8000


class CustomHttpServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    server_address = ("", PORT)
    with CustomHttpServer(server_address, AuthHandler) as httpd:
        logger.info(f"Local AI News Aggregator Server running at http://localhost:{PORT}")
        logger.info(f" - Auth endpoint: http://localhost:{PORT}/api/auth")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            logger.info("Server stopped.")

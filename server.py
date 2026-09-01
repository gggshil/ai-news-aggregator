import os
import http.server
import socketserver
import logging
from api.auth import handler as AuthHandler

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

PORT = int(os.getenv("PORT", "8000"))
HOST = "0.0.0.0"


class ProductionHttpServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    server_address = (HOST, PORT)
    with ProductionHttpServer(server_address, AuthHandler) as httpd:
        logger.info(f"AI News Aggregator Server running on http://{HOST}:{PORT}")
        logger.info(f" - Health endpoint: http://{HOST}:{PORT}/health")
        logger.info(f" - Auth endpoint:   http://{HOST}:{PORT}/api/auth")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            logger.info("Server stopped.")

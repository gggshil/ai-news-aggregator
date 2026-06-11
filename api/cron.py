from http.server import BaseHTTPRequestHandler
import json
from app.daily_runner import run_daily_pipeline

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            import os
            print("Vercel Cron Triggered: Starting Daily Pipeline...")
            print("Available environment variables:", sorted(list(os.environ.keys())))
            # Run the daily pipeline
            result = run_daily_pipeline(hours=24, top_n=10)
            
            # Respond with the pipeline summary
            self.send_response(200 if result.get("success") else 500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            response_data = {
                "status": "success" if result.get("success") else "failed",
                "summary": result
            }
            self.wfile.write(json.dumps(response_data).encode('utf-8'))
            
        except Exception as e:
            print(f"Error executing Vercel Cron: {e}")
            self.send_response(500)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(f"Pipeline failed: {str(e)}".encode('utf-8'))
        finally:
            try:
                from app.database.connection import db_session
                db_session.remove()
                print("Database connection successfully returned to pool.")
            except Exception as ex:
                print(f"Error closing DB session: {ex}")
            
    def do_POST(self):
        # Allow POST request triggers as well
        self.do_GET()

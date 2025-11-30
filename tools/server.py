#!/usr/bin/env python3
"""
Simple HTTP server for serving the built documentation.

This server is designed to serve static files from the 'public' directory
which is created after running 'make build'.

Usage:
    python3 tools/server.py [port]

Example:
    python3 tools/server.py 8000
"""

import argparse
import http.server
import os
import socketserver
import sys
from functools import partial
from pathlib import Path


class DocumentationHandler(http.server.SimpleHTTPRequestHandler):
    """Custom HTTP request handler for documentation serving."""

    def __init__(self, *args, directory=None, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def end_headers(self):
        """Add security headers to response."""
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'SAMEORIGIN')
        super().end_headers()

    def log_message(self, format, *args):
        """Log HTTP requests with timestamp."""
        sys.stderr.write("[%s] %s - %s\n" %
                         (self.log_date_time_string(),
                          self.address_string(),
                          format % args))


def get_public_directory():
    """Get the path to the public directory."""
    script_dir = Path(__file__).parent.resolve()
    repo_root = script_dir.parent
    public_dir = repo_root / "public"
    return public_dir


def main():
    """Main entry point for the server."""
    parser = argparse.ArgumentParser(
        description="Serve the built documentation from the public directory."
    )
    parser.add_argument(
        "port",
        nargs="?",
        type=int,
        default=8000,
        help="Port to serve on (default: 8000)"
    )
    parser.add_argument(
        "--bind",
        "-b",
        default="127.0.0.1",
        help="Address to bind to (default: 127.0.0.1)"
    )

    args = parser.parse_args()

    public_dir = get_public_directory()

    if not public_dir.exists():
        print(f"Error: Public directory not found at {public_dir}")
        print("Please run 'make build' first to generate the documentation.")
        sys.exit(1)

    os.chdir(public_dir)

    handler = partial(DocumentationHandler, directory=str(public_dir))

    with socketserver.TCPServer((args.bind, args.port), handler) as httpd:
        print(f"Serving documentation at http://{args.bind}:{args.port}/")
        print(f"Serving files from: {public_dir}")
        print("Press Ctrl+C to stop the server.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")
            sys.exit(0)


if __name__ == "__main__":
    main()

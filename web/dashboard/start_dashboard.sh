#!/bin/bash
# Quick launcher for moveOmeter Dashboard

echo "🚀 Starting moveOmeter Dashboard..."
echo ""
echo "Dashboard will be available at: http://localhost:8000"
echo "Press Ctrl+C to stop"
echo ""

cd "$(dirname "$0")"
python3 -m http.server 8000

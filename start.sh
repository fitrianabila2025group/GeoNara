#!/bin/bash
echo "======================================================="
echo "   S H A D O W B R O K E R   -   macOS / Linux Start   "
echo "======================================================="
echo ""

# Check for Node.js
if ! command -v npm &> /dev/null; then
    echo "[!] ERROR: npm is not installed. Please install Node.js (https://nodejs.org/)"
    exit 1
fi

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "[!] ERROR: python3 is not installed. Please install Python 3.10+ (https://python.org/)"
    exit 1
fi

echo "[*] Setting up Backend Environment..."
cd backend
if [ ! -d "venv" ]; then
    echo "[*] Creating Python Virtual Environment..."
    python3 -m venv venv
fi

echo "[*] Installing Backend dependencies..."
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # In case someone runs this in Git Bash on Windows
    source venv/Scripts/activate
else
    source venv/bin/activate
fi
pip install -r requirements.txt
cd ..

echo "[*] Setting up Frontend Environment..."
cd frontend
if [ ! -d "node_modules" ]; then
    echo "[*] Installing Frontend dependencies..."
    npm install
fi

echo ""
echo "======================================================="
echo "  🚀 Starting Services...                              "
echo "  Dashboard will be available at: http://localhost:3000"
echo "  Keep this window open! Note: Initial load takes ~10s "
echo "======================================================="
echo ""

# Start both services (npm run dev automatically calls the python backend on Mac/Linux if scripts are configured cross-platform)
npm run dev

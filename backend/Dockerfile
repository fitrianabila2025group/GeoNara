FROM python:3.10-slim

WORKDIR /app

# Runtime tools used by backend services:
# - node: AIS stream proxy (ais_proxy.js)
# - curl: network fallback path in services/network_utils.py
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0t64 \
    libnspr4 \
    libnss3 \
    libatk1.0-0t64 \
    libatk-bridge2.0-0t64 \
    libdbus-1-3 \
    libcups2t64 \
    libxcb1 \
    libxkbcommon0 \
    libatspi2.0-0t64 \
    libx11-6 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libcairo2 \
    libpango-1.0-0 \
    libasound2t64 \
    curl \
    nodejs \
    npm \
  && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN playwright install chromium

# Install Node.js dependency for ais_proxy.js
COPY package*.json ./
RUN npm install --omit=dev

# Copy source code
COPY . .

# Expose port
EXPOSE 8000

# Start FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

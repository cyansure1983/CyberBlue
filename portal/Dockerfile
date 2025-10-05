FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies including Docker CLI, YARA, and Git
RUN apt-get update && apt-get install -y \
    curl \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    yara \
    git \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install Sigma CLI and backends for threat hunting
RUN pip install --no-cache-dir sigma-cli pysigma-backend-elasticsearch pysigma-backend-opensearch

# Configure git to trust mounted rule directories
RUN git config --global --add safe.directory /opt/yara-rules && \
    git config --global --add safe.directory /opt/sigma-rules

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/logs

# Expose port
EXPOSE 5500

# Set environment variables
ENV PORT=5500
ENV FLASK_ENV=production

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5500/health || exit 1

# Start the application
CMD ["python3", "app.py"] 
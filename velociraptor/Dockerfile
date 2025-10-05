FROM debian:bullseye-slim

# Install dependencies
RUN apt update && apt install -y curl file && rm -rf /var/lib/apt/lists/*

# Download the latest Velociraptor binary automatically
RUN curl -s https://api.github.com/repos/Velocidex/velociraptor/releases/latest \
    | grep "browser_download_url" \
    | grep "linux-amd64" \
    | cut -d '"' -f 4 \
    | xargs curl -L -o /usr/local/bin/velociraptor \
    && chmod +x /usr/local/bin/velociraptor

# Copy config and entrypoint
COPY server.config.yaml /velociraptor/server.config.yaml
COPY entrypoint.sh /entrypoint.sh

# Ensure entrypoint is executable
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

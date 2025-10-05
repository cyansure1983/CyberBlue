#!/bin/bash

echo "[*] Ensuring Velociraptor binary is executable..."
chmod +x /usr/local/bin/velociraptor

echo "[*] Adding admin user from environment variables..."
/usr/local/bin/velociraptor --config /velociraptor/server.config.yaml user add --role=administrator "$VEL_USER" "$VEL_PASSWORD" || echo "[!] User may already exist."

echo "[*] Starting Velociraptor frontend..."
exec /usr/local/bin/velociraptor --config /velociraptor/server.config.yaml frontend

# CyberBlue Velociraptor Agent Deployment System

## 📋 Overview

This system allows users to easily deploy Velociraptor agents to Windows, Linux, and macOS systems directly from the CyberBlue portal. Each agent is dynamically generated with the correct server IP and CA certificate, ensuring zero-configuration deployment.

## 🚀 Features

- **Dynamic Configuration**: Agents are generated on-demand with custom server IP
- **Multi-OS Support**: Windows, Linux, and macOS installation scripts
- **Automated Installation**: One-command deployment with error handling
- **Secure by Design**: Uses CA certificates extracted from server config
- **Web Interface**: Beautiful UI in the portal under "Agents" tab

## 📁 Directory Structure

```
/velociraptor/agents/
├── templates/              # Template files for agent generation
│   ├── client.config.template.yaml
│   ├── install-windows.ps1.template
│   ├── install-linux.sh.template
│   └── install-macos.sh.template
├── generated/              # Generated agent packages (per session)
│   └── {session-id}/
│       ├── client.config.yaml
│       ├── install-windows.ps1
│       ├── install-linux.sh
│       └── install-macos.sh
└── README.md              # This file
```

## 🔧 How It Works

### 1. User Access
- Navigate to CyberBlue Portal: `https://YOUR_IP:5443`
- Click on "Agents" tab (between Tools and Rules)

### 2. Configuration
- Enter your server IP address (e.g., `192.168.1.100`)
- Click "Generate Agents"

### 3. Generation Process
- Portal extracts CA certificate from `/velociraptor/server.config.yaml`
- Creates unique session ID for this generation
- Populates templates with server IP and CA certificate
- Generates 4 files:
  - `client.config.yaml` - Velociraptor client configuration
  - `install-windows.ps1` - Windows PowerShell installer
  - `install-linux.sh` - Linux bash installer  
  - `install-macos.sh` - macOS bash installer

### 4. Download & Deploy
- Download appropriate installer for your OS
- Execute on target machine (requires admin/sudo privileges)
- Agent auto-connects to server on port 8000
- Appears in Velociraptor GUI within 1-2 minutes

## 🖥️ Installation Instructions

### Windows
```powershell
# Run PowerShell as Administrator
.\install-windows.ps1
```

**What it does:**
- Downloads latest Velociraptor binary
- Installs to `C:\Program Files\Velociraptor\`
- Registers as Windows Service
- Starts automatically

### Linux
```bash
# Ubuntu/Debian/CentOS/RHEL
chmod +x install-linux.sh
sudo ./install-linux.sh
```

**What it does:**
- Downloads latest Velociraptor binary
- Installs to `/usr/local/bin/velociraptor`
- Creates systemd service
- Enables auto-start on boot

### macOS
```bash
# macOS 10.14+ (Intel & Apple Silicon)
chmod +x install-macos.sh
sudo ./install-macos.sh
```

**What it does:**
- Downloads latest Velociraptor binary (arm64/amd64)
- Installs to `/usr/local/sbin/velociraptor`
- Creates LaunchDaemon
- Starts automatically

## 🔐 Security Considerations

### CA Certificate Extraction
- Automatically extracted from server config
- Unique to each CyberBlue installation
- Ensures agents only connect to legitimate server

### Port Requirements
- **Port 8000**: Agent-to-server communication (MUST be open)
- **Port 7000**: GUI access (already configured)

### Firewall Rules
```bash
# On CyberBlue server
sudo ufw allow 8000/tcp comment 'Velociraptor agent communication'
sudo ufw status
```

## 🛠️ Troubleshooting

### Agent Not Appearing
1. Check agent service status:
   - Windows: `Get-Service Velociraptor`
   - Linux: `systemctl status velociraptor`
   - macOS: `launchctl list | grep velociraptor`

2. Verify port 8000 is accessible:
   ```bash
   telnet YOUR_SERVER_IP 8000
   ```

3. Check agent logs:
   - Windows: Event Viewer → Application logs
   - Linux: `journalctl -u velociraptor -f`
   - macOS: `/var/log/velociraptor.log`

### Connection Issues
- Ensure firewall allows port 8000
- Verify server IP is correct
- Check network connectivity
- Confirm Velociraptor container is running:
  ```bash
  docker ps | grep velociraptor
  ```

### Certificate Errors
- Regenerate agents with correct server IP
- Ensure using agents from same CyberBlue installation
- Don't mix agents from different servers

## 📊 Verification

### On Server (Velociraptor GUI)
1. Access: `https://YOUR_SERVER_IP:7000`
2. Login: `admin` / `cyberblue`
3. Navigate to "Show All Clients"
4. Look for hostname of deployed machine

### On Client
```bash
# Check if agent is running
# Windows
Get-Service Velociraptor | Format-List

# Linux
systemctl status velociraptor

# macOS
launchctl list | grep velociraptor
```

## 🔄 Updates

Agents will automatically receive updates from the server. To manually update:

### Windows
```powershell
Restart-Service Velociraptor
```

### Linux
```bash
sudo systemctl restart velociraptor
```

### macOS
```bash
sudo launchctl unload /Library/LaunchDaemons/com.velocidex.velociraptor.plist
sudo launchctl load /Library/LaunchDaemons/com.velocidex.velociraptor.plist
```

## 📝 API Endpoints

For programmatic access:

```bash
# Check system status
GET /api/agents/info

# Generate agents
POST /api/agents/generate
Content-Type: application/json
{"server_ip": "192.168.1.100"}

# Download files
GET /api/agents/download/{session_id}/{filename}
```

## ⚙️ Configuration

### Change Agent Port
If you need to use a different port (not 8000), update:

1. `docker-compose.yml`: Change port mapping
2. `server.config.yaml`: Update Frontend bind_port
3. Regenerate all agents

### Custom Velociraptor Version
Scripts auto-download latest version. To pin a version, modify templates to use specific release URL.

## 🎯 Best Practices

1. **Network Security**: Only expose port 8000 to trusted networks
2. **Agent Management**: Use Velociraptor GUI to manage deployed agents
3. **Regular Updates**: Keep Velociraptor server and agents updated
4. **Monitoring**: Monitor agent connections in the portal
5. **Documentation**: Document which machines have agents installed

## 📚 Additional Resources

- Velociraptor Documentation: https://docs.velociraptor.app/
- CyberBlue GitHub: https://github.com/CyberBlue0/CyberBlue
- Velociraptor GitHub: https://github.com/Velocidex/velociraptor

## 🐛 Known Issues

None currently. Report issues on GitHub.

## 📄 License

Same as CyberBlue - MIT License
For educational use only.

---

**Generated by CyberBlue Agent Deployment System**
Version 1.0 - October 2025



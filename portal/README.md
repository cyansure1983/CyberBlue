# 🛡️ CyberBlueBox Portal

A beautiful, modern web portal that provides centralized access to all CyberBlueBox security tools with comprehensive changelog functionality.

## 🚀 Features

- **Centralized Access**: Single point of entry to all security tools
- **Real-time Status**: Live container monitoring and system status
- **Comprehensive Changelog**: Track all system activities, container changes, and user actions
- **Responsive Design**: Works perfectly on desktop, tablet, and mobile
- **Tool Categorization**: Tools organized by security function (DFIR, SIEM, CTI, etc.)
- **Protocol Support**: Automatic HTTP/HTTPS detection and routing
- **Modern UI**: Beautiful gradient design with smooth animations
- **Python Backend**: Fast, reliable Flask-based API with threading support

## 🛠️ Tools Included

| Tool | Port | Category | Description |
|------|------|----------|-------------|
| Velociraptor | 7000 | DFIR | Digital Forensics & Incident Response |
| Wazuh Dashboard | 7001 | SIEM | Security Information & Event Management |
| MISP | 7003 | CTI | Threat Intelligence Platform |
| CyberChef | 7004 | Utility | Cyber Swiss Army Knife |
| TheHive | 7005 | SOAR | Incident Response & Case Management |
| Cortex | 7006 | SOAR | Automated Threat Analysis |
| FleetDM | 7007 | Management | Endpoint Visibility & Management |
| Arkime | 7008 | IDS | Packet Capture & Analysis |
| Evebox | 7015 | IDS | Suricata Log Viewer |
| Wireshark | 7011 | Utility | Network Protocol Analyzer |
| MITRE Navigator | 7013 | CTI | ATT&CK Matrix Visualization |
| Portainer | 9443 | Management | Container Management |

## 📋 Changelog Features

- **Automatic Logging**: All system activities are automatically logged
- **Container Monitoring**: Real-time tracking of container start/stop/status changes
- **API Activity**: Logs all API calls and user interactions
- **Filtering**: Filter entries by level (info, warning, error, success)
- **Statistics**: View changelog statistics and activity metrics
- **Persistent Storage**: All entries are saved to JSON file for persistence

## 🏃‍♂️ Quick Start

### Option 1: Using Docker Compose (Recommended)

The portal is automatically included in the main CyberBlueBox docker-compose.yml:

```bash
# Start all services including the portal
docker-compose up -d

# Access the portal
open http://localhost:8080
```

### Option 2: Standalone Development

```bash
# Navigate to portal directory
cd portal

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start development server
python app.py

# Access the portal
open http://localhost:8080
```

### Option 3: Production Build

```bash
# Build the Docker image
docker build -t cyberbluebox-portal .

# Run the container
docker run -d \
  --name cyberbluebox-portal \
  -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  cyberbluebox-portal
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 5500 | Port for the portal server |
| `NODE_ENV` | production | Environment mode |

### API Endpoints

- `GET /` - Main portal page
- `GET /api/containers` - Get running container count
- `GET /api/containers/status` - Get detailed container status
- `GET /api/tools` - Get available tools configuration
- `GET /api/changelog` - Get changelog entries (supports `limit` and `level` params)
- `GET /api/changelog/stats` - Get changelog statistics
- `POST /api/changelog/add` - Add a new changelog entry
- `GET /health` - Health check endpoint

### Changelog Entry Structure

```json
{
  "timestamp": "2024-01-15T10:30:00",
  "action": "container_started",
  "details": "Container 'velociraptor' started with status: Up 2 minutes",
  "user": "system",
  "level": "info",
  "id": 1
}
```

## 🎨 Customization

### Adding New Tools

To add a new tool to the portal, edit the `tools` array in `app.py`:

```python
{
    "name": "Your Tool Name",
    "description": "Tool description",
    "port": 7014,
    "icon": "fas fa-icon-name",
    "category": "category-name",
    "categoryName": "Category Display Name",
    "protocols": ["http", "https"]
}
```

### Adding Custom Changelog Entries

```python
# From Python code
changelog_manager.add_entry(
    action="custom_action",
    details="Custom details here",
    user="username",
    level="info"  # info, warning, error, success
)

# From API
curl -X POST http://localhost:8080/api/changelog/add \
  -H "Content-Type: application/json" \
  -d '{
    "action": "custom_action",
    "details": "Custom details",
    "user": "username",
    "level": "info"
  }'
```

### Styling

The portal uses CSS custom properties for easy theming. Key variables:

```css
:root {
    --primary-gradient: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    --card-background: rgba(255,255,255,0.95);
    --text-primary: #333;
    --text-secondary: #666;
}
```

## 🔒 Security Considerations

- The portal requires access to Docker socket for container monitoring
- All tool access is through direct port forwarding
- No authentication is implemented (add your own if needed)
- Consider using reverse proxy with SSL termination
- Changelog entries are stored in plain JSON (consider encryption for sensitive data)

## 🐛 Troubleshooting

### Portal Not Loading
```bash
# Check if container is running
docker ps | grep cyberbluebox-portal

# Check logs
docker logs cyberbluebox-portal

# Restart the service
docker-compose restart cyberbluebox-portal
```

### Tools Not Accessible
```bash
# Verify all containers are running
docker-compose ps

# Check port mappings
docker-compose port cyberbluebox-portal 8080
```

### API Endpoints Not Working
```bash
# Test health endpoint
curl http://localhost:8080/health

# Test container API
curl http://localhost:8080/api/containers

# Test changelog API
curl http://localhost:8080/api/changelog
```

### Changelog Issues
```bash
# Check changelog file
cat changelog.json

# Check portal logs
tail -f portal.log

# Test changelog API
curl http://localhost:8080/api/changelog/stats
```

## 📊 Changelog Statistics

The portal provides comprehensive statistics about system activity:

- **Total Entries**: Total number of changelog entries
- **Recent Activity**: Entries from the last 24 hours
- **By Level**: Breakdown by info/warning/error/success
- **By Action**: Most common actions performed

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🙏 Acknowledgments

- Built with ❤️ for the cybersecurity community
- Icons provided by Font Awesome
- Design inspired by modern security dashboards
- Python Flask backend for reliability and performance 
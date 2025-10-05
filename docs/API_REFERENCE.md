# 🔌 CyberBlue Portal API Reference

Complete API documentation for the CyberBlue Portal backend system.

---

## 🎯 Overview

The CyberBlue Portal provides a RESTful API for managing containers, monitoring system status, and integrating with external tools. All endpoints return JSON responses and support CORS for web integration.

### Base URL
```
http://YOUR_IP:5500/api
```

### Authentication
Currently, the API operates without authentication. For production deployments, implement API key authentication.

---

## 📊 **System Status Endpoints**

### GET /api/status
Get overall system status and health information.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "uptime": "2d 5h 30m",
  "version": "2.0.0",
  "containers": {
    "total": 15,
    "running": 14,
    "stopped": 1,
    "unhealthy": 0
  },
  "resources": {
    "cpu_usage": "45%",
    "memory_usage": "8.2GB/16GB",
    "disk_usage": "45GB/100GB"
  }
}
```

### GET /api/health
Simple health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## 🐳 **Container Management Endpoints**

### GET /api/containers
List all CyberBlue containers with status information.

**Query Parameters:**
- `status` (optional): Filter by status (`running`, `stopped`, `restarting`)
- `category` (optional): Filter by category (`siem`, `dfir`, `cti`, `soar`)

**Response:**
```json
{
  "containers": [
    {
      "id": "abc123...",
      "name": "wazuh-dashboard",
      "status": "running",
      "health": "healthy",
      "category": "siem",
      "ports": ["7001:5601"],
      "uptime": "2d 5h 30m",
      "image": "wazuh/wazuh-dashboard:4.12.0",
      "cpu_usage": "2.5%",
      "memory_usage": "512MB",
      "url": "https://YOUR_IP:7001"
    }
  ],
  "total": 15,
  "running": 14
}
```

### GET /api/containers/{container_name}
Get detailed information about a specific container.

**Response:**
```json
{
  "id": "abc123...",
  "name": "wazuh-dashboard",
  "status": "running",
  "health": "healthy",
  "category": "siem",
  "description": "Wazuh SIEM Dashboard",
  "ports": ["7001:5601"],
  "uptime": "2d 5h 30m",
  "started_at": "2024-01-13T05:00:00Z",
  "image": "wazuh/wazuh-dashboard:4.12.0",
  "resources": {
    "cpu_usage": "2.5%",
    "memory_usage": "512MB",
    "memory_limit": "2GB",
    "network_io": {
      "rx_bytes": "1.2MB",
      "tx_bytes": "2.8MB"
    }
  },
  "environment": {
    "INDEXER_USERNAME": "admin",
    "WAZUH_API_URL": "https://wazuh.manager"
  },
  "volumes": [
    "./wazuh/config/wazuh_dashboard/opensearch_dashboards.yml:/usr/share/wazuh-dashboard/config/opensearch_dashboards.yml"
  ],
  "url": "https://YOUR_IP:7001",
  "logs_url": "/api/containers/wazuh-dashboard/logs"
}
```

### POST /api/containers/{container_name}/start
Start a stopped container.

**Response:**
```json
{
  "success": true,
  "message": "Container wazuh-dashboard started successfully",
  "container": {
    "name": "wazuh-dashboard",
    "status": "running"
  }
}
```

### POST /api/containers/{container_name}/stop
Stop a running container.

**Response:**
```json
{
  "success": true,
  "message": "Container wazuh-dashboard stopped successfully",
  "container": {
    "name": "wazuh-dashboard",
    "status": "stopped"
  }
}
```

### POST /api/containers/{container_name}/restart
Restart a container.

**Response:**
```json
{
  "success": true,
  "message": "Container wazuh-dashboard restarted successfully",
  "container": {
    "name": "wazuh-dashboard",
    "status": "running"
  }
}
```

### GET /api/containers/{container_name}/logs
Get container logs.

**Query Parameters:**
- `lines` (optional): Number of log lines to return (default: 100)
- `since` (optional): Only return logs since timestamp
- `follow` (optional): Stream logs (WebSocket)

**Response:**
```json
{
  "logs": [
    {
      "timestamp": "2024-01-15T10:30:00Z",
      "level": "info",
      "message": "Wazuh dashboard started successfully"
    }
  ],
  "lines_returned": 100,
  "total_lines": 1500
}
```

---

## 📈 **Monitoring Endpoints**

### GET /api/metrics
Get system performance metrics.

**Response:**
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "system": {
    "cpu": {
      "total_usage": "45%",
      "load_average": [1.2, 1.5, 1.8]
    },
    "memory": {
      "total": "16GB",
      "used": "8.2GB",
      "free": "7.8GB",
      "usage_percent": 51.25
    },
    "disk": {
      "total": "100GB",
      "used": "45GB",
      "free": "55GB",
      "usage_percent": 45.0
    },
    "network": {
      "rx_bytes": "1.2TB",
      "tx_bytes": "800GB"
    }
  },
  "docker": {
    "containers_running": 14,
    "images_count": 20,
    "volumes_count": 15,
    "networks_count": 2
  }
}
```

### GET /api/metrics/containers
Get performance metrics for all containers.

**Response:**
```json
{
  "containers": [
    {
      "name": "wazuh-dashboard",
      "cpu_usage": "2.5%",
      "memory_usage": "512MB",
      "memory_limit": "2GB",
      "memory_percent": 25.0,
      "network_io": {
        "rx_bytes": 1234567,
        "tx_bytes": 2345678
      },
      "block_io": {
        "read_bytes": 123456,
        "write_bytes": 234567
      }
    }
  ]
}
```

---

## 📝 **Changelog Endpoints**

### GET /api/changelog
Get system changelog and activity history.

**Query Parameters:**
- `limit` (optional): Number of entries to return (default: 50)
- `since` (optional): Only return entries since timestamp
- `action` (optional): Filter by action type (`start`, `stop`, `restart`)

**Response:**
```json
{
  "changelog": [
    {
      "id": "entry_123",
      "timestamp": "2024-01-15T10:30:00Z",
      "action": "restart",
      "target": "wazuh-dashboard",
      "user": "system",
      "status": "success",
      "message": "Container restarted successfully",
      "details": {
        "reason": "configuration_update",
        "duration": "15s"
      }
    }
  ],
  "total": 150,
  "page": 1,
  "pages": 3
}
```

### POST /api/changelog
Add a new changelog entry.

**Request Body:**
```json
{
  "action": "update",
  "target": "system",
  "message": "Updated configuration files",
  "details": {
    "files_modified": ["docker-compose.yml", ".env"]
  }
}
```

**Response:**
```json
{
  "success": true,
  "entry_id": "entry_124",
  "message": "Changelog entry added successfully"
}
```

---

## 🔧 **Configuration Endpoints**

### GET /api/config
Get current system configuration.

**Response:**
```json
{
  "host_ip": "10.0.0.40",
  "portal_port": 5500,
  "environment": "production",
  "services": {
    "wazuh": {
      "enabled": true,
      "port": 7001,
      "url": "https://10.0.0.40:7001"
    },
    "misp": {
      "enabled": true,
      "port": 7003,
      "url": "https://10.0.0.40:7003"
    }
  },
  "security": {
    "ssl_enabled": true,
    "auth_required": false
  }
}
```

### PUT /api/config
Update system configuration (requires restart).

**Request Body:**
```json
{
  "portal_port": 5501,
  "security": {
    "auth_required": true
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Configuration updated successfully",
  "restart_required": true
}
```

---

## 🔄 **Deployment Endpoints**

### POST /api/deploy/pull
Pull latest Docker images for all services.

**Response:**
```json
{
  "success": true,
  "message": "Image pull started",
  "job_id": "pull_job_123",
  "estimated_duration": "10-15 minutes"
}
```

### POST /api/deploy/restart-all
Restart all CyberBlue services.

**Request Body (optional):**
```json
{
  "force": false,
  "wait_for_health": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "Restart initiated",
  "job_id": "restart_job_124",
  "estimated_duration": "5-10 minutes"
}
```

### GET /api/deploy/jobs/{job_id}
Get status of a deployment job.

**Response:**
```json
{
  "job_id": "pull_job_123",
  "status": "running",
  "progress": 65,
  "started_at": "2024-01-15T10:30:00Z",
  "estimated_completion": "2024-01-15T10:45:00Z",
  "logs": [
    "Pulling wazuh/wazuh-dashboard:4.12.0...",
    "Pull complete for wazuh-dashboard"
  ]
}
```

---

## 🔍 **Search and Filter Endpoints**

### GET /api/search/containers
Search containers by name, category, or status.

**Query Parameters:**
- `q`: Search query
- `category`: Filter by category
- `status`: Filter by status

**Response:**
```json
{
  "query": "wazuh",
  "results": [
    {
      "name": "wazuh-dashboard",
      "category": "siem",
      "status": "running",
      "relevance": 0.95
    }
  ],
  "total": 1
}
```

### GET /api/search/logs
Search container logs across all services.

**Query Parameters:**
- `q`: Search query
- `container`: Specific container to search
- `level`: Log level filter (`error`, `warn`, `info`)
- `since`: Only search logs since timestamp

**Response:**
```json
{
  "query": "error",
  "results": [
    {
      "container": "wazuh-dashboard",
      "timestamp": "2024-01-15T10:30:00Z",
      "level": "error",
      "message": "Connection failed to indexer",
      "context": "...full log entry..."
    }
  ],
  "total": 5
}
```

---

## 📡 **WebSocket Endpoints**

### WS /api/ws/status
Real-time system status updates.

**Message Format:**
```json
{
  "type": "status_update",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "container": "wazuh-dashboard",
    "status": "running",
    "health": "healthy"
  }
}
```

### WS /api/ws/logs
Real-time log streaming.

**Message Format:**
```json
{
  "type": "log_entry",
  "timestamp": "2024-01-15T10:30:00Z",
  "container": "wazuh-dashboard",
  "level": "info",
  "message": "Dashboard started successfully"
}
```

---

## 🔒 **Security Endpoints**

### GET /api/security/certificates
Get SSL certificate information.

**Response:**
```json
{
  "certificates": [
    {
      "service": "wazuh-dashboard",
      "subject": "CN=wazuh.dashboard",
      "issuer": "CN=wazuh-ca",
      "valid_from": "2024-01-01T00:00:00Z",
      "valid_until": "2025-01-01T00:00:00Z",
      "days_until_expiry": 300,
      "status": "valid"
    }
  ]
}
```

### POST /api/security/regenerate-certs
Regenerate SSL certificates for all services.

**Response:**
```json
{
  "success": true,
  "message": "Certificate regeneration started",
  "job_id": "cert_regen_125"
}
```

---

## 📊 **Integration Examples**

### Python Client Example
```python
import requests
import json

class CyberBlueAPI:
    def __init__(self, base_url):
        self.base_url = base_url
        
    def get_containers(self):
        response = requests.get(f"{self.base_url}/api/containers")
        return response.json()
    
    def restart_container(self, name):
        response = requests.post(f"{self.base_url}/api/containers/{name}/restart")
        return response.json()
    
    def get_metrics(self):
        response = requests.get(f"{self.base_url}/api/metrics")
        return response.json()

# Usage
api = CyberBlueAPI("http://10.0.0.40:5500")
containers = api.get_containers()
metrics = api.get_metrics()
```

### JavaScript Client Example
```javascript
class CyberBlueAPI {
    constructor(baseUrl) {
        this.baseUrl = baseUrl;
    }
    
    async getContainers() {
        const response = await fetch(`${this.baseUrl}/api/containers`);
        return await response.json();
    }
    
    async restartContainer(name) {
        const response = await fetch(`${this.baseUrl}/api/containers/${name}/restart`, {
            method: 'POST'
        });
        return await response.json();
    }
    
    async getMetrics() {
        const response = await fetch(`${this.baseUrl}/api/metrics`);
        return await response.json();
    }
}

// Usage
const api = new CyberBlueAPI('http://10.0.0.40:5500');
api.getContainers().then(containers => console.log(containers));
```

### cURL Examples
```bash
# Get system status
curl -X GET http://10.0.0.40:5500/api/status

# Restart container
curl -X POST http://10.0.0.40:5500/api/containers/wazuh-dashboard/restart

# Get container logs
curl -X GET "http://10.0.0.40:5500/api/containers/wazuh-dashboard/logs?lines=50"

# Search containers
curl -X GET "http://10.0.0.40:5500/api/search/containers?q=wazuh&status=running"
```

---

## ❌ **Error Handling**

### Standard Error Response
```json
{
  "success": false,
  "error": {
    "code": "CONTAINER_NOT_FOUND",
    "message": "Container 'invalid-name' not found",
    "details": {
      "available_containers": ["wazuh-dashboard", "misp-core"]
    }
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Common Error Codes
- `CONTAINER_NOT_FOUND`: Requested container doesn't exist
- `CONTAINER_NOT_RUNNING`: Operation requires running container
- `DOCKER_ERROR`: Docker daemon error
- `PERMISSION_DENIED`: Insufficient permissions
- `INVALID_PARAMETER`: Invalid request parameter
- `RATE_LIMITED`: Too many requests
- `INTERNAL_ERROR`: Server internal error

### HTTP Status Codes
- `200`: Success
- `400`: Bad Request
- `404`: Not Found
- `429`: Too Many Requests
- `500`: Internal Server Error
- `503`: Service Unavailable

---

## 📚 **SDK Development**

The CyberBlue Portal API is designed to be easily integrated into monitoring tools, automation scripts, and third-party applications. Consider developing SDKs for:

- **Python**: For automation and monitoring scripts
- **Go**: For high-performance integrations
- **Node.js**: For web applications and dashboards
- **PowerShell**: For Windows administration

---

*This API reference is continuously updated. Check the GitHub repository for the latest version and examples.*

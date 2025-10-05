#!/usr/bin/env python3
"""
CyberBlueSOC Portal - Secure Python Flask Backend
Central access point for all security tools with authentication and HTTPS
"""

import os
import json
import subprocess
import logging
from datetime import datetime
from flask import Flask, render_template, jsonify, request, redirect, url_for, flash
from flask_cors import CORS
from flask_login import login_required, current_user, login_user, logout_user
import threading
import time
import signal
import sys
import ssl

# Import our authentication modules
from auth import init_auth, require_auth, require_role
from forms import LoginForm, RegistrationForm, ChangePasswordForm

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('portal.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuration
PORT = int(os.environ.get('PORT', 5500))
HTTPS_PORT = int(os.environ.get('HTTPS_PORT', 5443))
CHANGELOG_FILE = 'changelog.json'
CONTAINER_STATUS_FILE = 'container_status.json'
SSL_CERT_PATH = os.environ.get('SSL_CERT_PATH', './ssl/cert.pem')
SSL_KEY_PATH = os.environ.get('SSL_KEY_PATH', './ssl/key.pem')
ENABLE_HTTPS = os.environ.get('ENABLE_HTTPS', 'true').lower() == 'true'

# Initialize authentication
auth_manager = init_auth(app)

# Global flag for graceful shutdown
shutdown_flag = False


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    global shutdown_flag
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_flag = True
    sys.exit(0)


# Register signal handlers
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


class ChangelogManager:
    """Manages changelog entries for all system activities"""

    def __init__(self, changelog_file):
        self.changelog_file = changelog_file
        self.load_changelog()

    def load_changelog(self):
        """Load existing changelog from file"""
        try:
            if os.path.exists(self.changelog_file):
                with open(self.changelog_file, 'r') as f:
                    self.changelog = json.load(f)
            else:
                self.changelog = {
                    "entries": [],
                    "metadata": {
                        "created": datetime.now().isoformat(),
                        "version": "1.0.0",
                        "total_entries": 0
                    }
                }
                self.save_changelog()
        except Exception as e:
            logger.error(f"Error loading changelog: {e}")
            self.changelog = {"entries": [], "metadata": {
                "created": datetime.now().isoformat(), "version": "1.0.0", "total_entries": 0}}

    def save_changelog(self):
        """Save changelog to file"""
        try:
            with open(self.changelog_file, 'w') as f:
                json.dump(self.changelog, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving changelog: {e}")

    def add_entry(self, action, details, user="system", level="info"):
        """Add a new changelog entry"""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "action": action,
            "details": details,
            "user": user,
            "level": level,
            "id": len(self.changelog["entries"]) + 1
        }

        self.changelog["entries"].append(entry)
        self.changelog["metadata"]["total_entries"] = len(
            self.changelog["entries"])
        self.save_changelog()

        logger.info(f"Changelog entry added: {action} - {details}")
        return entry

    def get_entries(self, limit=None, level=None):
        """Get changelog entries with optional filtering"""
        entries = self.changelog["entries"]

        if level:
            entries = [e for e in entries if e["level"] == level]

        if limit:
            entries = entries[-limit:]

        return entries

    def get_stats(self):
        """Get changelog statistics"""
        entries = self.changelog["entries"]
        stats = {
            "total_entries": len(entries),
            "by_level": {},
            "by_action": {},
            "recent_activity": len([e for e in entries if self._is_recent(e["timestamp"])])
        }

        for entry in entries:
            # Count by level
            level = entry["level"]
            stats["by_level"][level] = stats["by_level"].get(level, 0) + 1

            # Count by action
            action = entry["action"]
            stats["by_action"][action] = stats["by_action"].get(action, 0) + 1

        return stats

    def _is_recent(self, timestamp, hours=24):
        """Check if timestamp is within recent hours"""
        try:
            entry_time = datetime.fromisoformat(timestamp)
            return (datetime.now() - entry_time).total_seconds() < hours * 3600
        except:
            return False


class ContainerMonitor:
    """Monitors Docker container status for all tools"""

    def __init__(self, changelog_manager):
        self.changelog = changelog_manager
        self.previous_status = {}
        self.monitoring = False
        self.monitor_thread = None
        self.container_status = {}

    def start_monitoring(self):
        """Start container monitoring in background thread"""
        if not self.monitoring:
            self.monitoring = True
            self.monitor_thread = threading.Thread(
                target=self._monitor_loop, daemon=True)
            self.monitor_thread.start()
            logger.info("Container monitoring started")

    def stop_monitoring(self):
        """Stop container monitoring"""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join()
        logger.info("Container monitoring stopped")

    def _monitor_loop(self):
        """Background monitoring loop"""
        while self.monitoring:
            try:
                current_status = self.get_all_container_status()
                self._check_status_changes(current_status)
                self.container_status = current_status
                self.previous_status = {
                    name: status["status"] for name, status in current_status.items()}
                time.sleep(30)  # Check every 30 seconds
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                time.sleep(60)  # Wait longer on error

    def _check_status_changes(self, current_status):
        """Check for container status changes and log them"""
        current_containers = {name: status["status"]
                              for name, status in current_status.items()}

        for name, status_info in current_status.items():
            if name not in self.previous_status:
                # New container started
                self.changelog.add_entry(
                    "container_started",
                    f"Container '{name}' started with status: {status_info['status']}",
                    level="info"
                )
            elif self.previous_status[name] != status_info["status"]:
                # Container status changed
                self.changelog.add_entry(
                    "container_status_changed",
                    f"Container '{name}' status changed from '{self.previous_status[name]}' to '{status_info['status']}'",
                    level="warning"
                )

        # Check for stopped containers
        for name in self.previous_status:
            if name not in current_containers:
                self.changelog.add_entry(
                    "container_stopped",
                    f"Container '{name}' stopped",
                    level="warning"
                )

    def get_container_count(self):
        """Get running container count"""
        try:
            result = subprocess.run(
                ['docker', 'ps', '--format', 'table {{.Names}}'],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                return len(lines) - 1  # Subtract header line
            return 0
        except Exception as e:
            logger.error(f"Error getting container count: {e}")
            return 0

    def get_all_container_status(self):
        """Get detailed status for all containers"""
        try:
            result = subprocess.run(
                ['docker', 'ps', '-a', '--format',
                    '{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}\t{{.Size}}'],
                capture_output=True, text=True, timeout=10
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                containers = {}

                for line in lines:
                    if line.strip():
                        # Split by tab character
                        parts = line.split('\t')
                        if len(parts) >= 5:
                            name = parts[0].strip()
                            status = parts[1].strip()
                            ports = parts[2].strip()
                            image = parts[3].strip()
                            size = parts[4].strip()

                            # Determine status type
                            if "Up" in status:
                                status_type = "running"
                                status_color = "green"
                            elif "Exited" in status:
                                status_type = "stopped"
                                status_color = "red"
                            elif "Created" in status:
                                status_type = "created"
                                status_color = "yellow"
                            else:
                                status_type = "unknown"
                                status_color = "gray"

                            containers[name] = {
                                "name": name,
                                "status": status_type,
                                "status_text": status,
                                "status_color": status_color,
                                "ports": ports,
                                "image": image,
                                "size": size,
                                "last_updated": datetime.now().isoformat()
                            }

                return containers
            return {}
        except Exception as e:
            logger.error(f"Error getting container status: {e}")
            return {}

    def get_tool_container_status(self):
        """Get status for tool-specific containers"""
        all_containers = self.get_all_container_status()
        tool_containers = {}

        # Map tool names to possible container names (with fallbacks)
        tool_container_map = {
            "velociraptor": ["velociraptor"],
            "wazuh": ["wazuh", "wazuh-dashboard", "cyber-blue-test-wazuh.dashboard-1"],
            "wazuh-dashboard": ["wazuh", "wazuh-dashboard", "cyber-blue-test-wazuh.dashboard-1"],
            "misp": ["misp", "misp-core", "cyber-blue-test-misp-core-1"],
            "cyberchef": ["cyber-blue-test-cyberchef-1", "cyberchef"],
            "thehive": ["cyber-blue-test-thehive-1", "thehive"],
            "cortex": ["cyber-blue-test-cortex-1", "cortex"],
            "fleetdm": ["fleet-server", "cyber-blue-test-fleet-server-1"],
            "arkime": ["arkime-test", "arkime", "cyber-blue-test-arkime-1"],
            "caldera": ["caldera", "cyber-blue-test-caldera-1"],
            "evebox": ["evebox", "cyber-blue-test-evebox-1"],
            "wireshark": ["wireshark", "cyber-blue-test-wireshark-1"],
            "mitre": ["mitre-navigator", "cyber-blue-test-mitre-navigator-1"],
            "mitre-navigator": ["mitre-navigator", "cyber-blue-test-mitre-navigator-1"],
            "portainer": ["portainer", "cyber-blue-test-portainer-1"],
            "shuffle": ["shuffle-frontend", "cyber-blue-test-shuffle-frontend-1"],
            "openvas": ["openvas"]
        }

        def find_container_name(possible_names):
            """Find the first matching container name from the list"""
            for name in possible_names:
                if name in all_containers:
                    return name
            return None

        for tool_name, possible_names in tool_container_map.items():
            container_name = find_container_name(possible_names)
            if container_name:
                tool_containers[tool_name] = all_containers[container_name]
            else:
                # Container not found
                tool_containers[tool_name] = {
                    "name": possible_names[0] if possible_names else tool_name,
                    "status": "not_found",
                    "status_text": "Container not found",
                    "status_color": "gray",
                    "ports": "",
                    "image": "",
                    "size": "",
                    "last_updated": datetime.now().isoformat()
                }

        return tool_containers

    def get_container_name_for_tool(self, tool_name):
        """Get the actual container name for a tool"""
        all_containers = self.get_all_container_status()

        # Map tool names to possible container names (with fallbacks)
        tool_container_map = {
            "velociraptor": ["velociraptor"],
            "wazuh": ["wazuh", "wazuh-dashboard", "cyber-blue-test-wazuh.dashboard-1"],
            "wazuh-dashboard": ["wazuh", "wazuh-dashboard", "cyber-blue-test-wazuh.dashboard-1"],
            "misp": ["misp", "misp-core", "cyber-blue-test-misp-core-1"],
            "cyberchef": ["cyber-blue-test-cyberchef-1", "cyberchef"],
            "thehive": ["cyber-blue-test-thehive-1", "thehive"],
            "cortex": ["cyber-blue-test-cortex-1", "cortex"],
            "fleetdm": ["fleet-server", "cyber-blue-test-fleet-server-1"],
            "arkime": ["arkime-test", "arkime", "cyber-blue-test-arkime-1"],
            "caldera": ["caldera", "cyber-blue-test-caldera-1"],
            "evebox": ["evebox", "cyber-blue-test-evebox-1"],
            "wireshark": ["wireshark", "cyber-blue-test-wireshark-1"],
            "mitre": ["mitre-navigator", "cyber-blue-test-mitre-navigator-1"],
            "mitre-navigator": ["mitre-navigator", "cyber-blue-test-mitre-navigator-1"],
            "portainer": ["portainer", "cyber-blue-test-portainer-1"],
            "shuffle": ["shuffle-frontend", "cyber-blue-test-shuffle-frontend-1"],
            "openvas": ["openvas"]
        }

        if tool_name in tool_container_map:
            for name in tool_container_map[tool_name]:
                if name in all_containers:
                    return name

        # If not found in tool mapping, return the original name
        return tool_name

    def start_container(self, container_name):
        """Start a specific container"""
        try:
            # Try to find the actual container name if it's a tool name
            actual_container_name = self.get_container_name_for_tool(
                container_name)

            result = subprocess.run(
                ['docker', 'start', actual_container_name],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                self.changelog.add_entry(
                    "container_started",
                    f"Container '{actual_container_name}' started manually",
                    level="info"
                )
                return {"success": True, "message": f"Container {actual_container_name} started successfully"}
            else:
                return {"success": False, "message": f"Failed to start container: {result.stderr}"}
        except Exception as e:
            logger.error(f"Error starting container {container_name}: {e}")
            return {"success": False, "message": f"Error starting container: {str(e)}"}

    def stop_container(self, container_name):
        """Stop a specific container"""
        try:
            # Try to find the actual container name if it's a tool name
            actual_container_name = self.get_container_name_for_tool(
                container_name)

            result = subprocess.run(
                ['docker', 'stop', actual_container_name],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                self.changelog.add_entry(
                    "container_stopped",
                    f"Container '{actual_container_name}' stopped manually",
                    level="info"
                )
                return {"success": True, "message": f"Container {actual_container_name} stopped successfully"}
            else:
                return {"success": False, "message": f"Failed to stop container: {result.stderr}"}
        except Exception as e:
            logger.error(f"Error stopping container {container_name}: {e}")
            return {"success": False, "message": f"Error stopping container: {str(e)}"}

    def restart_container(self, container_name):
        """Restart a specific container"""
        try:
            # Try to find the actual container name if it's a tool name
            actual_container_name = self.get_container_name_for_tool(
                container_name)

            result = subprocess.run(
                ['docker', 'restart', actual_container_name],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                self.changelog.add_entry(
                    "container_restarted",
                    f"Container '{actual_container_name}' restarted manually",
                    level="info"
                )
                return {"success": True, "message": f"Container {actual_container_name} restarted successfully"}
            else:
                return {"success": False, "message": f"Failed to restart container: {result.stderr}"}
        except Exception as e:
            logger.error(f"Error restarting container {container_name}: {e}")
            return {"success": False, "message": f"Error restarting container: {str(e)}"}


# Initialize managers
changelog_manager = ChangelogManager(CHANGELOG_FILE)
container_monitor = ContainerMonitor(changelog_manager)

# Authentication Routes


@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page"""
    if current_user.is_authenticated:
        return redirect(url_for('index'))

    form = LoginForm()

    if form.validate_on_submit():
        user = auth_manager.authenticate_user(
            form.username.data, form.password.data)
        if user:
            login_user(user, remember=form.remember_me.data)
            changelog_manager.add_entry(
                action="user_login",
                details=f"User '{user.username}' logged in successfully",
                user=user.username,
                level="info"
            )
            next_page = request.args.get('next')
            return redirect(next_page) if next_page else redirect(url_for('index'))
        else:
            flash('Invalid username or password', 'error')
            changelog_manager.add_entry(
                action="login_failed",
                details=f"Failed login attempt for username '{form.username.data}'",
                user="anonymous",
                level="warning"
            )

    return render_template('login.html', form=form)


@app.route('/logout')
@login_required
def logout():
    """Logout user"""
    username = current_user.username
    logout_user()
    changelog_manager.add_entry(
        action="user_logout",
        details=f"User '{username}' logged out",
        user=username,
        level="info"
    )
    flash('You have been logged out successfully', 'success')
    return redirect(url_for('login'))


@app.route('/api/auth/token', methods=['POST'])
def get_auth_token():
    """Get JWT token for API access"""
    data = request.get_json()
    if not data or 'username' not in data or 'password' not in data:
        return jsonify({'error': 'Username and password required'}), 400

    user = auth_manager.authenticate_user(data['username'], data['password'])
    if user:
        token = auth_manager.generate_jwt_token(user)
        return jsonify({
            'token': token,
            'user': user.to_dict(),
            'expires_in': 86400  # 24 hours
        })
    else:
        return jsonify({'error': 'Invalid credentials'}), 401


@app.route('/')
@login_required
def index():
    """Main portal page - now requires authentication"""
    changelog_manager.add_entry(
        action="portal_access",
        details=f"User '{current_user.username}' accessed the portal",
        user=current_user.username,
        level="info"
    )
    return render_template('index.html', user=current_user)


@app.route('/api/containers')
@require_auth
def get_containers():
    """Get container count API endpoint - requires authentication"""
    try:
        count = container_monitor.get_container_count()
        changelog_manager.add_entry(
            "api_call", f"Container count requested: {count} containers")
        return jsonify({"count": count})
    except Exception as e:
        logger.error(f"Error in container count API: {e}")
        return jsonify({"count": "Unknown", "error": str(e)}), 500


@app.route('/api/containers/status')
@require_auth
def get_container_status():
    """Get detailed container status API endpoint - requires authentication"""
    try:
        containers = container_monitor.get_all_container_status()
        changelog_manager.add_entry(
            "api_call", f"Container status requested: {len(containers)} containers")
        return jsonify({"containers": containers})
    except Exception as e:
        logger.error(f"Error in container status API: {e}")
        return jsonify({"containers": {}, "error": str(e)}), 500


@app.route('/api/containers/tools')
def get_tool_container_status():
    """Get tool-specific container status API endpoint"""
    try:
        tool_containers = container_monitor.get_tool_container_status()
        changelog_manager.add_entry(
            "api_call", f"Tool container status requested: {len(tool_containers)} tools")
        return jsonify({"tool_containers": tool_containers})
    except Exception as e:
        logger.error(f"Error in tool container status API: {e}")
        return jsonify({"tool_containers": {}, "error": str(e)}), 500


@app.route('/api/containers/<container_name>/start', methods=['POST'])
def start_container(container_name):
    """Start a specific container API endpoint"""
    try:
        result = container_monitor.start_container(container_name)
        changelog_manager.add_entry(
            "container_action", f"Container '{container_name}' start requested", user="api_user")
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error starting container {container_name}: {e}")
        return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500


@app.route('/api/containers/<container_name>/stop', methods=['POST'])
def stop_container(container_name):
    """Stop a specific container API endpoint"""
    try:
        result = container_monitor.stop_container(container_name)
        changelog_manager.add_entry(
            "container_action", f"Container '{container_name}' stop requested", user="api_user")
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error stopping container {container_name}: {e}")
        return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500


@app.route('/api/containers/<container_name>/restart', methods=['POST'])
def restart_container(container_name):
    """Restart a specific container API endpoint"""
    try:
        result = container_monitor.restart_container(container_name)
        changelog_manager.add_entry(
            "container_action", f"Container '{container_name}' restart requested", user="api_user")
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error restarting container {container_name}: {e}")
        return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500


@app.route('/api/containers/stats')
def get_container_stats():
    """Get container statistics API endpoint"""
    try:
        all_containers = container_monitor.get_all_container_status()
        tool_containers = container_monitor.get_tool_container_status()

        # Calculate statistics
        total_containers = len(all_containers)
        running_containers = len(
            [c for c in all_containers.values() if c["status"] == "running"])
        stopped_containers = len(
            [c for c in all_containers.values() if c["status"] == "stopped"])

        # Tool-specific stats
        tool_running = len(
            [c for c in tool_containers.values() if c["status"] == "running"])
        tool_stopped = len(
            [c for c in tool_containers.values() if c["status"] == "stopped"])
        tool_not_found = len(
            [c for c in tool_containers.values() if c["status"] == "not_found"])

        stats = {
            "total_containers": total_containers,
            "running_containers": running_containers,
            "stopped_containers": stopped_containers,
            "tool_containers": {
                "total": len(tool_containers),
                "running": tool_running,
                "stopped": tool_stopped,
                "not_found": tool_not_found
            },
            "health_percentage": round((running_containers / total_containers * 100) if total_containers > 0 else 0, 1),
            "last_updated": datetime.now().isoformat()
        }

        changelog_manager.add_entry(
            "api_call", f"Container stats requested: {stats['health_percentage']}% health")
        return jsonify(stats)
    except Exception as e:
        logger.error(f"Error in container stats API: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/changelog')
def get_changelog():
    """Get changelog entries API endpoint"""
    try:
        limit = request.args.get('limit', type=int)
        level = request.args.get('level')
        entries = changelog_manager.get_entries(limit=limit, level=level)
        return jsonify({"entries": entries})
    except Exception as e:
        logger.error(f"Error in changelog API: {e}")
        return jsonify({"entries": [], "error": str(e)}), 500


@app.route('/api/changelog/stats')
def get_changelog_stats():
    """Get changelog statistics API endpoint"""
    try:
        stats = changelog_manager.get_stats()
        return jsonify(stats)
    except Exception as e:
        logger.error(f"Error in changelog stats API: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/changelog/add', methods=['POST'])
def add_changelog_entry():
    """Add a new changelog entry API endpoint"""
    try:
        data = request.get_json()
        action = data.get('action', 'unknown')
        details = data.get('details', '')
        user = data.get('user', 'api_user')
        level = data.get('level', 'info')

        entry = changelog_manager.add_entry(action, details, user, level)
        return jsonify({"success": True, "entry": entry})
    except Exception as e:
        logger.error(f"Error adding changelog entry: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/api/force-start', methods=['POST'])
def force_start_system():
    """Force start system by restarting Docker and bringing up all services"""
    try:
        # Detect the project directory dynamically
        def find_project_directory():
            """Find the CyberBlue project directory dynamically"""
            # Since we're running in a container, we need to check paths on the host system
            # We know the most likely location is /home/ubuntu/CyberBlue
            host_possible_paths = [
                '/home/ubuntu/CyberBlue',
                '/opt/CyberBlue', 
                '/root/CyberBlue',
                '/home/*/CyberBlue',  # Wildcard for different users
            ]
            
            # First, try the most common location
            default_path = '/home/ubuntu/CyberBlue'
            logger.info(f"Using default CyberBlue project directory: {default_path}")
            return default_path

        project_dir = find_project_directory()
        
        changelog_manager.add_entry(
            "force_start_initiated",
            f"Force start system initiated from directory: {project_dir}",
            user=getattr(current_user, 'username', 'api_user'),
            level="info"
        )

        # Execute the force start commands
        def run_force_start():
            try:
                # Since restarting Docker from within a container causes issues,
                # let's try a simpler approach: just restart the containers without restarting Docker daemon
                
                logger.info("Force starting containers without Docker daemon restart...")
                
                # Step 1: Stop all containers first
                logger.info("Stopping all containers...")
                stop_cmd = [
                    'docker', 'run', '--rm', 
                    '-v', '/var/run/docker.sock:/var/run/docker.sock',
                    'alpine/docker:latest',
                    'sh', '-c', 'docker stop $(docker ps -q) 2>/dev/null || true'
                ]
                
                result1 = subprocess.run(
                    stop_cmd,
                    capture_output=True, text=True, timeout=60
                )
                
                logger.info(f"Container stop result: {result1.returncode}")
                if result1.stderr:
                    logger.info(f"Stop stderr: {result1.stderr}")

                # Step 2: Wait a moment
                logger.info("Waiting for containers to stop...")
                time.sleep(5)

                # Step 3: Start containers using docker compose from the host directory
                logger.info(f"Starting services in directory: {project_dir}")
                
                # Mount the project directory and run docker compose
                compose_cmd = [
                    'docker', 'run', '--rm', 
                    '-v', '/var/run/docker.sock:/var/run/docker.sock',
                    '-v', f'{project_dir}:{project_dir}',
                    '-w', project_dir,
                    'alpine/docker:latest',
                    'sh', '-c', 'apk add --no-cache docker-compose && docker-compose up -d'
                ]
                
                result2 = subprocess.run(
                    compose_cmd,
                    capture_output=True, text=True, timeout=300  # 5 minutes timeout
                )
                
                logger.info(f"Docker compose result: {result2.returncode}")
                if result2.stdout:
                    logger.info(f"Compose stdout: {result2.stdout}")
                if result2.stderr:
                    logger.info(f"Compose stderr: {result2.stderr}")
                
                if result2.returncode != 0:
                    # Try alternative approach with docker compose (newer syntax)
                    logger.info("Trying with newer docker compose syntax...")
                    compose_cmd_alt = [
                        'docker', 'run', '--rm', 
                        '-v', '/var/run/docker.sock:/var/run/docker.sock',
                        '-v', f'{project_dir}:{project_dir}',
                        '-w', project_dir,
                        'docker:latest',
                        'sh', '-c', 'docker compose up -d'
                    ]
                    
                    result3 = subprocess.run(
                        compose_cmd_alt,
                        capture_output=True, text=True, timeout=300
                    )
                    
                    logger.info(f"Alternative compose result: {result3.returncode}")
                    if result3.stdout:
                        logger.info(f"Alt stdout: {result3.stdout}")
                    if result3.stderr:
                        logger.info(f"Alt stderr: {result3.stderr}")
                    
                    if result3.returncode != 0:
                        changelog_manager.add_entry(
                            "force_start_failed",
                            f"Docker compose failed: {result2.stderr} | Alt: {result3.stderr}",
                            user=getattr(current_user, 'username', 'api_user'),
                            level="error"
                        )
                        return False

                changelog_manager.add_entry(
                    "force_start_completed",
                    f"Force start completed successfully in {project_dir}",
                    user=getattr(current_user, 'username', 'api_user'),
                    level="success"
                )
                return True

            except subprocess.TimeoutExpired:
                logger.error("Force start operation timed out")
                changelog_manager.add_entry(
                    "force_start_failed",
                    "Force start operation timed out",
                    user=getattr(current_user, 'username', 'api_user'),
                    level="error"
                )
                return False
            except Exception as e:
                logger.error(f"Error during force start: {e}")
                changelog_manager.add_entry(
                    "force_start_failed",
                    f"Force start error: {str(e)}",
                    user=getattr(current_user, 'username', 'api_user'),
                    level="error"
                )
                return False

        # Run the force start in a separate thread to avoid blocking the response
        import threading
        
        def async_force_start():
            success = run_force_start()
            if success:
                logger.info("Force start completed successfully")
            else:
                logger.error("Force start failed")

        force_start_thread = threading.Thread(target=async_force_start, daemon=True)
        force_start_thread.start()

        return jsonify({
            "success": True, 
            "message": f"Force start initiated successfully in {project_dir}. This may take several minutes.",
            "project_directory": project_dir
        })

    except Exception as e:
        logger.error(f"Error in force start API: {e}")
        changelog_manager.add_entry(
            "force_start_error",
            f"Force start API error: {str(e)}",
            user=getattr(current_user, 'username', 'api_user'),
            level="error"
        )
        return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500


@app.route('/api/server-info')
def get_server_info():
    """Get server information API endpoint"""
    try:
        import socket

        # Get the actual server IP (not localhost)
        def get_server_ip():
            try:
                # Priority 1: Use HOST_IP environment variable (set in Docker Compose)
                import os
                host_ip = os.environ.get('HOST_IP')
                if host_ip:
                    logger.info(
                        f"Using HOST_IP environment variable: {host_ip}")
                    return host_ip

                # Priority 2: Detect if we're in a container and try to find host IP
                if os.path.exists('/.dockerenv'):
                    logger.info(
                        "Detected container environment, attempting to find host IP")

                    # Try to get default gateway (Docker host)
                    try:
                        import subprocess
                        result = subprocess.run(['ip', 'route', 'show', 'default'],
                                                capture_output=True, text=True, timeout=5)
                        if result.returncode == 0:
                            for line in result.stdout.split('\n'):
                                if 'default via' in line:
                                    gateway = line.split('via')[1].split()[0]
                                    logger.info(f"Found gateway: {gateway}")

                                    # Try to detect the actual host IP from network interfaces
                                    try:
                                        # Get network interfaces to find the host network
                                        net_result = subprocess.run(['ip', 'addr', 'show'],
                                                                    capture_output=True, text=True, timeout=5)
                                        if net_result.returncode == 0:
                                            # Look for private IP addresses (avoiding localhost)
                                            import re
                                            # Match common private IP ranges: 10.x.x.x, 192.168.x.x, 172.16-31.x.x
                                            ip_pattern = r'inet ((?:10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(?:1[6-9]|2[0-9]|3[0-1])\.\d+\.\d+))/'
                                            matches = re.findall(
                                                ip_pattern, net_result.stdout)
                                            if matches:
                                                # Filter out localhost and use the first valid private IP
                                                valid_ips = [
                                                    ip for ip in matches if ip != '127.0.0.1']
                                                if valid_ips:
                                                    detected_host = valid_ips[0]
                                                    logger.info(
                                                        f"Detected host IP from network interfaces: {detected_host}")
                                                    return detected_host
                                    except Exception as e:
                                        logger.warning(
                                            f"Could not detect host IP from interfaces: {e}")

                                    # Fallback: Use gateway IP if it's a private IP
                                    if (gateway.startswith('10.') or
                                        gateway.startswith('192.168.') or
                                            gateway.startswith('172.')):
                                        logger.info(
                                            f"Using gateway as host IP: {gateway}")
                                        return gateway
                                    break
                    except Exception as e:
                        logger.warning(f"Could not determine gateway: {e}")

                # Priority 3: Traditional socket method for non-container environments
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                    s.connect(("8.8.8.8", 80))
                    detected_ip = s.getsockname()[0]

                    # If it's a container IP, try to find the host IP
                    if detected_ip.startswith('172.'):
                        logger.warning(
                            f"Detected container IP {detected_ip}, trying to find host IP")
                        # Try to find the actual host IP from request headers or environment
                        return request.environ.get('HTTP_X_FORWARDED_FOR',
                                                   request.environ.get('HTTP_X_REAL_IP',
                                                                       request.environ.get('REMOTE_ADDR', detected_ip)))

                    return detected_ip

            except Exception as e:
                logger.error(f"Error detecting server IP: {e}")
                # Final fallback - try to get from request context
                try:
                    return request.environ.get('HTTP_HOST', 'localhost').split(':')[0]
                except:
                    return 'localhost'

        server_ip = get_server_ip()
        hostname = socket.gethostname()

        return jsonify({
            "hostname": hostname,
            "server_ip": server_ip,
            "port": PORT,
            "portal_url": f"http://{server_ip}:{PORT}",
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        logger.error(f"Error getting server info: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/health')
def health_check():
    """Health check endpoint"""
    try:
        container_stats = container_monitor.get_container_count()
        return jsonify({
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "container_count": container_stats,
            "changelog_entries": len(changelog_manager.changelog["entries"]),
            "monitoring_active": container_monitor.monitoring
        })
    except Exception as e:
        logger.error(f"Error in health check: {e}")
        return jsonify({
            "status": "degraded",
            "timestamp": datetime.now().isoformat(),
            "error": str(e)
        }), 500


@app.route('/api/tools')
def get_tools():
    """Get available tools configuration"""
    tools = [
        {
            "name": "Velociraptor",
            "description": "Digital Forensics and Incident Response platform for live endpoint forensics and threat hunting.",
            "port": 7000,
            "icon": "fas fa-search",
            "category": "dfir",
            "categoryName": "DFIR",
            "protocols": ["https"],
            "credentials": {
                "username": "admin",
                "password": "cyberblue"
            }
        },
        {
            "name": "Wazuh Dashboard",
            "description": "SIEM dashboard for log analysis, alerting, and security monitoring with Kibana-style interface.",
            "port": 7001,
            "icon": "fas fa-chart-line",
            "category": "siem",
            "categoryName": "SIEM",
            "protocols": ["https"],
            "credentials": {
                "username": "admin",
                "password": "SecretPassword"
            }
        },
        {
            "name": "Shuffle",
            "description": "Security automation and orchestration platform for building, testing, and deploying security workflows.",
            "port": 7002,
            "icon": "fas fa-random",
            "category": "soar",
            "categoryName": "SOAR",
            "protocols": ["https"],
            "credentials": {
                "username": "admin",
                "password": "password"
            }
        },
        {
            "name": "MISP",
            "description": "Threat Intelligence Platform for sharing, storing, and correlating indicators of compromise.",
            "port": 7003,
            "icon": "fas fa-brain",
            "category": "cti",
            "categoryName": "CTI",
            "protocols": ["https"],
            "credentials": {
                "username": "admin@admin.test",
                "password": "admin"
            }
        },
        {
            "name": "CyberChef",
            "description": "Cyber Swiss Army Knife for data analysis, encoding, decoding, and forensics operations.",
            "port": 7004,
            "icon": "fas fa-utensils",
            "category": "utility",
            "categoryName": "Utility",
            "protocols": ["http"],
            "credentials": {
                "note": "No authentication required"
            }
        },
        {
            "name": "TheHive",
            "description": "Incident Response and Case Management platform for security operations teams.",
            "port": 7005,
            "icon": "fas fa-bug",
            "category": "soar",
            "categoryName": "SOAR",
            "protocols": ["http"],
            "credentials": {
                "username": "admin@thehive.local",
                "password": "secret"
            }
        },
        {
            "name": "Cortex",
            "description": "Automated threat analysis platform with analyzers for TheHive integration.",
            "port": 7006,
            "icon": "fas fa-robot",
            "category": "soar",
            "categoryName": "SOAR",
            "protocols": ["http"],
            "credentials": {
                "username": "admin",
                "password": "admin"
            }
        },
        {
            "name": "FleetDM",
            "description": "Osquery-based endpoint visibility and fleet management platform.",
            "port": 7007,
            "icon": "fas fa-desktop",
            "category": "management",
            "categoryName": "Management",
            "protocols": ["http"],
            "credentials": {
                "username": "admin",
                "password": "admin123"
            }
        },
        {
            "name": "Arkime",
            "description": "Full packet capture and session search engine for network analysis.",
            "port": 7008,
            "icon": "fas fa-network-wired",
            "category": "network analysis",
            "categoryName": "NETWORK ANALYSIS",
            "protocols": ["http"],
            "credentials": {
                "username": "admin",
                "password": "admin"
            }
        },
        {
            "name": "Caldera",
            "description": "Automated adversary emulation platform for security testing and red team operations.",
            "port": 7009,
            "icon": "fas fa-chess-king",
            "category": "attack-simulation",
            "categoryName": "ATTACK SIMULATION",
            "protocols": ["http"],
            "credentials": {
                "username": "admin",
                "password": "admin"
            }
        },
        {
            "name": "Evebox",
            "description": "Web-based viewer for Suricata EVE JSON logs and alert management.",
            "port": 7015,
            "icon": "fas fa-eye",
            "category": "ids",
            "categoryName": "INTRUSION DETECTION",
            "protocols": ["https"],
            "credentials": {
                "note": "No authentication required"
            }
        },
        {
            "name": "Wireshark",
            "description": "Network protocol analyzer for deep packet inspection and network troubleshooting.",
            "port": 7099,
            "icon": "fas fa-filter",
            "category": "network analysis",
            "categoryName": "NETWORK ANALYSIS",
            "protocols": ["https"],
            "credentials": {
                "username": "admin",
                "password": "cyberblue"
            }
        },
        {
            "name": "MITRE Navigator",
            "description": "Interactive ATT&CK matrix for threat modeling and attack path visualization.",
            "port": 7013,
            "icon": "fas fa-sitemap",
            "category": "cti",
            "categoryName": "CTI",
            "protocols": ["http"],
            "credentials": {
                "note": "No authentication required"
            }
        },
        {
            "name": "Portainer",
            "description": "Web-based container management interface for Docker and Kubernetes. ⚠️ NOTE: RESTART to be able to set the password!",
            "port": 9443,
            "icon": "fas fa-ship",
            "category": "management",
            "categoryName": "Management",
            "protocols": ["https"],
            "credentials": {
                "username": "admin",
                "password": "cyberblue123"
            }
        },
        {
            "name": "OpenVAS",
            "description": "Enterprise-grade vulnerability scanner with comprehensive security testing and reporting capabilities. ⚠️ NOTE: First startup takes 10-15 minutes to initialize vulnerability feeds. Please wait for full initialization.",
            "port": 7014,
            "icon": "fas fa-shield-alt",
            "category": "vulnerability",
            "categoryName": "VULNERABILITY MANAGEMENT",
            "protocols": ["http"],
            "credentials": {
                "username": "admin",
                "password": "cyberblue"
            }
        }
    ]
    return jsonify({"tools": tools})


@app.route('/api/dashboard/metrics')
def get_dashboard_metrics():
    """Get comprehensive dashboard metrics for enhanced visualization"""
    try:
        import psutil
        import time
        from datetime import datetime, timedelta

        # System metrics
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')

        # Container metrics
        all_containers = container_monitor.get_all_container_status()
        tool_containers = container_monitor.get_tool_container_status()

        running_containers = len(
            [c for c in all_containers.values() if c["status"] == "running"])
        stopped_containers = len(
            [c for c in all_containers.values() if c["status"] == "stopped"])
        total_containers = len(all_containers)

        # Tool-specific health
        tool_health = {}
        for tool_name, container_info in tool_containers.items():
            tool_health[tool_name] = {
                "status": container_info["status"],
                "health": "healthy" if container_info["status"] == "running" else "unhealthy",
                "uptime": container_info.get("status_text", "unknown")
            }

        # Security categories health
        categories = {
            "dfir": ["velociraptor"],
            "siem": ["wazuh", "wazuh-dashboard"],
            "soar": ["shuffle", "thehive", "cortex", "caldera"],
            "cti": ["misp", "mitre-navigator"],
            "ids": ["evebox"],
            "network analysis": ["wireshark", "arkime"],
            "utility": ["cyberchef"],
            "management": ["fleetdm", "portainer"],
            "vulnerability": ["openvas"]
        }

        category_health = {}
        for category, tools in categories.items():
            healthy_tools = 0
            total_tools = len(tools)
            for tool in tools:
                if tool in tool_containers and tool_containers[tool]["status"] == "running":
                    healthy_tools += 1

            health_percentage = (
                healthy_tools / total_tools * 100) if total_tools > 0 else 0
            category_health[category] = {
                "health_percentage": round(health_percentage, 1),
                "healthy_tools": healthy_tools,
                "total_tools": total_tools,
                "status": "healthy" if health_percentage >= 80 else "degraded" if health_percentage >= 50 else "critical"
            }

        # Recent activity from changelog
        recent_entries = changelog_manager.get_entries(limit=10)
        activity_summary = {
            "container_starts": len([e for e in recent_entries if "started" in e.get("action", "")]),
            "container_stops": len([e for e in recent_entries if "stopped" in e.get("action", "")]),
            "api_calls": len([e for e in recent_entries if "api_call" in e.get("action", "")]),
            "errors": len([e for e in recent_entries if e.get("level") == "error"])
        }

        metrics = {
            "timestamp": datetime.now().isoformat(),
            "system": {
                "cpu_percent": round(cpu_percent, 1),
                "memory_percent": round(memory.percent, 1),
                "memory_used_gb": round(memory.used / (1024**3), 2),
                "memory_total_gb": round(memory.total / (1024**3), 2),
                "disk_percent": round(disk.percent, 1),
                "disk_used_gb": round(disk.used / (1024**3), 2),
                "disk_total_gb": round(disk.total / (1024**3), 2)
            },
            "containers": {
                "total": total_containers,
                "running": running_containers,
                "stopped": stopped_containers,
                "health_percentage": round((running_containers / total_containers * 100) if total_containers > 0 else 0, 1)
            },
            "tools": tool_health,
            "categories": category_health,
            "activity": activity_summary,
            "uptime": datetime.now().isoformat()
        }

        changelog_manager.add_entry("api_call", "Dashboard metrics requested")
        return jsonify(metrics)

    except Exception as e:
        logger.error(f"Error getting dashboard metrics: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/dashboard/trends')
def get_dashboard_trends():
    """Get trending data for charts and graphs"""
    try:
        # For now, we'll generate sample trending data
        # In a real implementation, this would come from a time-series database
        from datetime import datetime, timedelta
        import random

        now = datetime.now()
        hours = []
        cpu_data = []
        memory_data = []
        container_data = []

        # Generate 24 hours of sample data
        for i in range(24):
            timestamp = now - timedelta(hours=23-i)
            hours.append(timestamp.strftime("%H:%M"))

            # Simulate realistic trending data
            cpu_data.append(round(random.uniform(10, 80), 1))
            memory_data.append(round(random.uniform(30, 90), 1))
            container_data.append(random.randint(25, 28))

        trends = {
            "timestamp": now.isoformat(),
            "timeframe": "24h",
            "data": {
                "labels": hours,
                "cpu_usage": cpu_data,
                "memory_usage": memory_data,
                "container_count": container_data
            }
        }

        changelog_manager.add_entry("api_call", "Dashboard trends requested")
        return jsonify(trends)

    except Exception as e:
        logger.error(f"Error getting dashboard trends: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/dashboard/security-events')
def get_security_events():
    """Get recent security-related events and alerts"""
    try:
        # Get recent changelog entries related to security
        recent_entries = changelog_manager.get_entries(limit=50)

        security_events = []
        for entry in recent_entries:
            # Classify events as security-related
            action = entry.get("action", "")
            details = entry.get("details", "")
            level = entry.get("level", "info")

            if any(keyword in action.lower() or keyword in details.lower()
                   for keyword in ["container_stopped", "container_started", "error", "failed", "warning"]):

                # Determine event severity
                if level == "error" or "failed" in details.lower():
                    severity = "high"
                    icon = "fas fa-exclamation-triangle"
                    color = "danger"
                elif level == "warning" or "stopped" in action:
                    severity = "medium"
                    icon = "fas fa-exclamation-circle"
                    color = "warning"
                else:
                    severity = "low"
                    icon = "fas fa-info-circle"
                    color = "info"

                security_events.append({
                    "id": entry.get("id"),
                    "timestamp": entry.get("timestamp"),
                    "title": action.replace("_", " ").title(),
                    "description": details,
                    "severity": severity,
                    "icon": icon,
                    "color": color,
                    "user": entry.get("user", "system")
                })

        # Limit to 20 most recent events
        security_events = security_events[:20]

        # Event statistics
        event_stats = {
            "total": len(security_events),
            "high": len([e for e in security_events if e["severity"] == "high"]),
            "medium": len([e for e in security_events if e["severity"] == "medium"]),
            "low": len([e for e in security_events if e["severity"] == "low"])
        }

        result = {
            "timestamp": datetime.now().isoformat(),
            "events": security_events,
            "statistics": event_stats
        }

        changelog_manager.add_entry(
            "api_call", f"Security events requested: {len(security_events)} events")
        return jsonify(result)

    except Exception as e:
        logger.error(f"Error getting security events: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/dashboard/network-stats')
def get_network_stats():
    """Get network statistics for containers and system"""
    try:
        import psutil

        # Get network interface statistics
        network_stats = psutil.net_io_counters()

        # Docker network information
        try:
            result = subprocess.run(
                ['docker', 'network', 'ls', '--format',
                    '{{.Name}}\t{{.Driver}}\t{{.Scope}}'],
                capture_output=True, text=True, timeout=10
            )

            networks = []
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split('\t')
                        if len(parts) >= 3:
                            networks.append({
                                "name": parts[0],
                                "driver": parts[1],
                                "scope": parts[2]
                            })
        except Exception:
            networks = []

        # Container port mappings
        all_containers = container_monitor.get_all_container_status()
        active_ports = []
        for container in all_containers.values():
            if container["status"] == "running" and container["ports"]:
                ports = container["ports"]
                if ports and ports != "":
                    active_ports.append({
                        "container": container["name"],
                        "ports": ports
                    })

        stats = {
            "timestamp": datetime.now().isoformat(),
            "system_network": {
                "bytes_sent": network_stats.bytes_sent,
                "bytes_recv": network_stats.bytes_recv,
                "packets_sent": network_stats.packets_sent,
                "packets_recv": network_stats.packets_recv,
                "errors_in": network_stats.errin,
                "errors_out": network_stats.errout
            },
            "docker_networks": networks,
            "active_ports": active_ports,
            "network_health": "healthy" if len(networks) > 0 else "warning"
        }

        changelog_manager.add_entry("api_call", "Network stats requested")
        return jsonify(stats)

    except Exception as e:
        logger.error(f"Error getting network stats: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    logger.info(f"🚀 Starting CyberBlueBox Portal on port {PORT}")
    logger.info(f"📱 Access the portal at: http://localhost:{PORT}")
    logger.info(f"🔧 API endpoints available at: http://localhost:{PORT}/api/")

    try:
        # Log initial startup
        changelog_manager.add_entry(
            "system_startup",
            "CyberBlueBox Portal started successfully with container monitoring",
            level="info"
        )

        # Start container monitoring in a separate thread to avoid blocking
        def start_monitoring_async():
            try:
                container_monitor.start_monitoring()
            except Exception as e:
                logger.error(f"Error starting container monitoring: {e}")

        monitoring_thread = threading.Thread(
            target=start_monitoring_async, daemon=True)
        monitoring_thread.start()

        # Start the Flask app with HTTPS support
        if ENABLE_HTTPS and os.path.exists(SSL_CERT_PATH) and os.path.exists(SSL_KEY_PATH):
            ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ssl_context.load_cert_chain(SSL_CERT_PATH, SSL_KEY_PATH)

            logger.info(f"🔒 Starting HTTPS server on port {HTTPS_PORT}")
            changelog_manager.add_entry(
                "system_startup", f"Portal started with HTTPS on port {HTTPS_PORT}", level="success")
            app.run(host='0.0.0.0', port=HTTPS_PORT, debug=False,
                    threaded=True, ssl_context=ssl_context)
        else:
            logger.warning(
                "⚠️  SSL certificates not found, starting HTTP server")
            logger.info(f"🌐 Starting HTTP server on port {PORT}")
            changelog_manager.add_entry(
                "system_startup", f"Portal started with HTTP on port {PORT}", level="warning")
            app.run(host='0.0.0.0', port=PORT, debug=False, threaded=True)

    except KeyboardInterrupt:
        logger.info("Shutting down CyberBlueBox Portal...")
        changelog_manager.add_entry(
            "system_shutdown", "CyberBlueBox Portal shut down gracefully")
    except Exception as e:
        logger.error(f"Error starting server: {e}")
        changelog_manager.add_entry(
            "system_error", f"Server startup error: {e}", level="error")
        # Don't exit immediately, try to log the error
        time.sleep(5)
        sys.exit(1)

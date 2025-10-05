#!/usr/bin/env python3
"""
CyberBlueSOC Portal Authentication Module
Handles user authentication, session management, and security
"""

import os
import jwt
import bcrypt
import json
from datetime import datetime, timedelta
from functools import wraps
from flask import request, jsonify, session, redirect, url_for
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user


class User(UserMixin):
    """User class for Flask-Login"""

    def __init__(self, id, username, email, role, password_hash=None):
        self.id = id
        self.username = username
        self.email = email
        self.role = role
        self.password_hash = password_hash
        # Don't set is_active directly, let UserMixin handle it

    def check_password(self, password):
        """Check if provided password matches hash"""
        if self.password_hash:
            return bcrypt.checkpw(password.encode('utf-8'), self.password_hash.encode('utf-8'))
        return False

    def to_dict(self):
        """Convert user to dictionary"""
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'role': self.role,
            'is_active': True
        }


class AuthManager:
    """Authentication manager for CyberBlueSOC Portal"""

    def __init__(self, app=None):
        self.app = app
        self.login_manager = LoginManager()
        self.users_file = 'users.json'
        self.secret_key = os.environ.get(
            'SECRET_KEY', 'cyberblue-secret-key-change-in-production')
        self.users = {}

        if app:
            self.init_app(app)

    def init_app(self, app):
        """Initialize authentication with Flask app"""
        app.secret_key = self.secret_key

        # Configure Flask-Login
        self.login_manager.init_app(app)
        self.login_manager.login_view = 'login'
        self.login_manager.login_message = 'Please log in to access the CyberBlueSOC Portal.'
        self.login_manager.login_message_category = 'info'

        # User loader callback
        @self.login_manager.user_loader
        def load_user(user_id):
            return self.get_user(user_id)

        # Load existing users
        self.load_users()

        # Create default admin user if no users exist
        if not self.users:
            self.create_default_admin()

    def load_users(self):
        """Load users from JSON file"""
        try:
            if os.path.exists(self.users_file):
                with open(self.users_file, 'r') as f:
                    users_data = json.load(f)
                    for user_data in users_data:
                        user = User(
                            id=user_data['id'],
                            username=user_data['username'],
                            email=user_data['email'],
                            role=user_data['role'],
                            password_hash=user_data['password_hash']
                        )
                        self.users[user.id] = user
        except Exception as e:
            print(f"Error loading users: {e}")
            self.users = {}

    def save_users(self):
        """Save users to JSON file"""
        try:
            users_data = []
            for user in self.users.values():
                users_data.append({
                    'id': user.id,
                    'username': user.username,
                    'email': user.email,
                    'role': user.role,
                    'password_hash': user.password_hash
                })

            with open(self.users_file, 'w') as f:
                json.dump(users_data, f, indent=2)
        except Exception as e:
            print(f"Error saving users: {e}")

    def create_default_admin(self):
        """Create default admin user"""
        admin_password = os.environ.get('ADMIN_PASSWORD', 'cyberblue123')
        password_hash = bcrypt.hashpw(admin_password.encode(
            'utf-8'), bcrypt.gensalt()).decode('utf-8')

        admin_user = User(
            id='admin',
            username='admin',
            email='admin@cyberblue.local',
            role='admin',
            password_hash=password_hash
        )

        self.users['admin'] = admin_user
        self.save_users()
        print(f"✅ Created default admin user: admin / {admin_password}")

    def get_user(self, user_id):
        """Get user by ID"""
        return self.users.get(user_id)

    def authenticate_user(self, username, password):
        """Authenticate user with username/password"""
        for user in self.users.values():
            if user.username == username and user.check_password(password):
                return user
        return None

    def create_user(self, username, email, password, role='user'):
        """Create a new user"""
        if any(user.username == username for user in self.users.values()):
            return None, "Username already exists"

        if any(user.email == email for user in self.users.values()):
            return None, "Email already exists"

        user_id = f"user_{len(self.users) + 1}"
        password_hash = bcrypt.hashpw(password.encode(
            'utf-8'), bcrypt.gensalt()).decode('utf-8')

        user = User(
            id=user_id,
            username=username,
            email=email,
            role=role,
            password_hash=password_hash
        )

        self.users[user_id] = user
        self.save_users()
        return user, "User created successfully"

    def delete_user(self, user_id):
        """Delete a user"""
        if user_id in self.users and user_id != 'admin':
            del self.users[user_id]
            self.save_users()
            return True
        return False

    def generate_jwt_token(self, user):
        """Generate JWT token for API access"""
        payload = {
            'user_id': user.id,
            'username': user.username,
            'role': user.role,
            'exp': datetime.utcnow() + timedelta(hours=24)
        }
        return jwt.encode(payload, self.secret_key, algorithm='HS256')

    def verify_jwt_token(self, token):
        """Verify JWT token"""
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=['HS256'])
            return self.get_user(payload['user_id'])
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None


def require_auth(f):
    """Decorator to require authentication for API endpoints"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Check for JWT token in headers
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            user = auth_manager.verify_jwt_token(token)
            if user:
                request.current_user = user
                return f(*args, **kwargs)

        # Check for session-based auth
        if current_user.is_authenticated:
            request.current_user = current_user
            return f(*args, **kwargs)

        return jsonify({'error': 'Authentication required'}), 401

    return decorated_function


def require_role(required_role):
    """Decorator to require specific role"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            user = getattr(request, 'current_user', current_user)
            if not user or user.role != required_role and user.role != 'admin':
                return jsonify({'error': 'Insufficient permissions'}), 403
            return f(*args, **kwargs)
        return decorated_function
    return decorator


# Global auth manager instance
auth_manager = None


def init_auth(app):
    """Initialize authentication for the app"""
    global auth_manager
    auth_manager = AuthManager(app)
    return auth_manager

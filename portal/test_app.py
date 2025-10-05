#!/usr/bin/env python3
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def index():
    return jsonify({"message": "CyberBlueBox Portal is working!", "status": "success"})

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "message": "Portal is running"})

if __name__ == '__main__':
    print("🚀 Starting test Flask app on port 5500")
    app.run(host='0.0.0.0', port=5500, debug=False) 
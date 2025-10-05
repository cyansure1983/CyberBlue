#!/bin/bash

echo "🚀 Starting CyberBlueBox Portal..."

# Check if we're in the right directory
if [ ! -f "app.py" ]; then
    echo "❌ Error: app.py not found. Please run this script from the portal directory."
    exit 1
fi

# Try to install dependencies if they're missing
echo "📦 Checking Python dependencies..."

# Try pip3 first
if command -v pip3 &> /dev/null; then
    echo "Installing dependencies with pip3..."
    pip3 install -r requirements.txt 2>/dev/null || {
        echo "⚠️  pip3 failed, trying alternative methods..."
        # Try installing individual packages
        pip3 install Flask Flask-CORS 2>/dev/null || echo "⚠️  pip3 installation failed"
    }
fi

# Try python3 -m pip as fallback
if command -v python3 &> /dev/null; then
    echo "Trying python3 -m pip..."
    python3 -m pip install Flask Flask-CORS 2>/dev/null || echo "⚠️  python3 -m pip failed"
fi

# Try system packages as last resort
if command -v apt &> /dev/null; then
    echo "Trying system packages..."
    sudo apt update -qq && sudo apt install -y python3-flask python3-flask-cors 2>/dev/null || echo "⚠️  system packages failed"
fi

# Check if Flask is available
python3 -c "import flask" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Error: Flask is not available. Please install Python dependencies manually:"
    echo "   pip3 install Flask Flask-CORS"
    echo "   or"
    echo "   sudo apt install python3-flask python3-flask-cors"
    exit 1
fi

# Check if Flask-CORS is available
python3 -c "import flask_cors" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Error: Flask-CORS is not available. Please install Python dependencies manually:"
    echo "   pip3 install Flask Flask-CORS"
    echo "   or"
    echo "   sudo apt install python3-flask python3-flask-cors"
    exit 1
fi

echo "✅ Dependencies check passed!"

# Set environment variables
export PORT=5500
export FLASK_ENV=production

echo "🌐 Starting portal on port $PORT..."
echo "📱 Access the portal at: http://localhost:$PORT"
echo "🔧 API endpoints available at: http://localhost:$PORT/api/"
echo ""
echo "Press Ctrl+C to stop the portal"
echo ""

# Start the portal
python3 app.py 
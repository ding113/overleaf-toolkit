#!/bin/bash
set -euo pipefail

echo "=== Overleaf All-in-One Container Starting ==="
echo "Container start time: $(date)"

# Function to handle shutdown signals
cleanup() {
    echo "Received shutdown signal, gracefully stopping services..."
    supervisorctl stop all || true
    pkill -TERM supervisord || true
    echo "Container stopped gracefully"
    exit 0
}

# Set up signal handlers for graceful shutdown
trap cleanup SIGTERM SIGINT

# Ensure all required data directories exist with correct permissions
echo "Setting up data directories and permissions..."

# MongoDB data directory
mkdir -p /data/mongo
chown -R mongodb:mongodb /data/mongo
chmod 755 /data/mongo

# Redis data directory  
mkdir -p /data/redis
chown -R redis:redis /data/redis
chmod 755 /data/redis

# Overleaf data directory
mkdir -p /var/lib/overleaf/{data,tmp,cache,uploads,templates,output}
chown -R sharelatex:sharelatex /var/lib/overleaf
chmod -R 755 /var/lib/overleaf

# Log directories
mkdir -p /var/log/supervisor /var/log/mongodb /var/log/redis
chmod 755 /var/log/supervisor /var/log/mongodb /var/log/redis

# Create MongoDB log file with correct permissions
touch /var/log/mongodb.log
chown mongodb:mongodb /var/log/mongodb.log

# Create Redis log file with correct permissions  
touch /var/log/redis.log
chown redis:redis /var/log/redis.log

echo "Data directories and permissions configured successfully"

# Load environment variables from config file if it exists
if [ -f /app/config/variables.env ]; then
    echo "Loading environment variables from config file..."
    set -a  # Automatically export all variables
    source /app/config/variables.env
    set +a
    echo "Environment variables loaded"
fi

# Set default environment variables if not provided
export OVERLEAF_APP_NAME="${OVERLEAF_APP_NAME:-Overleaf}"
export OVERLEAF_PORT="${OVERLEAF_PORT:-80}"
export MONGO_URL="${MONGO_URL:-mongodb://127.0.0.1:27017/sharelatex?replicaSet=overleaf}"
export REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
export REDIS_PORT="${REDIS_PORT:-6379}"

echo "Environment configured:"
echo "  App Name: $OVERLEAF_APP_NAME"
echo "  Port: $OVERLEAF_PORT"
echo "  MongoDB URL: $MONGO_URL"
echo "  Redis: $REDIS_HOST:$REDIS_PORT"

# Verify all scripts are executable
chmod +x /app/scripts/*.sh

# Start supervisor to manage all services
echo "Starting supervisor to manage all services..."
echo "Services will start in this order:"
echo "  1. MongoDB (priority 100)"
echo "  2. Redis (priority 200)" 
echo "  3. MongoDB Initialization (priority 300)"
echo "  4. Health Check Service (priority 400)"
echo "  5. Overleaf Service (priority 500, auto-started by init script)"

# Start supervisor in foreground mode
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
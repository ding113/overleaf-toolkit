#!/bin/bash
set -euo pipefail

echo "Starting Overleaf service..."

# Set environment variables for Overleaf
export SHARELATEX_APP_NAME="${OVERLEAF_APP_NAME:-Overleaf}"
export SHARELATEX_MONGO_URL="mongodb://127.0.0.1:27017/sharelatex?replicaSet=overleaf"
export SHARELATEX_REDIS_HOST="127.0.0.1"
export SHARELATEX_REDIS_PORT="6379"
export SHARELATEX_DATA_PATH="/var/lib/overleaf"

# Additional Overleaf configuration
export ENABLED_LINKED_FILE_TYPES="project_file,project_output_file"
export ENABLE_CONVERSIONS="true"
export EMAIL_CONFIRMATION_DISABLED="true"
export SHARELATEX_SITE_URL="http://localhost"
export SHARELATEX_NAV_TITLE="${OVERLEAF_APP_NAME:-Overleaf}"

# Ensure data directories exist with correct permissions
echo "Setting up data directories..."
mkdir -p /var/lib/overleaf/{data,tmp,cache}
chown -R sharelatex:sharelatex /var/lib/overleaf

# Wait for MongoDB to be ready
echo "Waiting for MongoDB replica set to be ready..."
for i in {1..30}; do
    if mongosh --quiet --eval "db.isMaster().ismaster" 2>/dev/null | grep -q "true"; then
        echo "MongoDB is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: MongoDB replica set not ready after 30 seconds"
        exit 1
    fi
    echo "Waiting for MongoDB replica set... ($i/30)"
    sleep 2
done

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
for i in {1..20}; do
    if redis-cli -h 127.0.0.1 -p 6379 ping >/dev/null 2>&1; then
        echo "Redis is ready"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "ERROR: Redis not ready after 20 seconds"
        exit 1
    fi
    echo "Waiting for Redis... ($i/20)"
    sleep 1
done

# Change to sharelatex user and start the service
echo "Starting Overleaf as sharelatex user..."
cd /var/lib/overleaf

# Start Overleaf using the original container's init system
exec /sbin/my_init
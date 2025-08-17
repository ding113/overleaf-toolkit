#!/bin/bash
set -euo pipefail

echo "MongoDB Initialization Script Starting..."

# Wait for MongoDB to start
echo "Waiting for MongoDB to start..."
for i in {1..60}; do
    if mongosh --quiet --eval "db.version()" 2>/dev/null; then
        echo "MongoDB is running"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "ERROR: MongoDB failed to start within 60 seconds"
        exit 1
    fi
    echo "Waiting for MongoDB... ($i/60)"
    sleep 1
done

# Check if replica set is already initialized
echo "Checking replica set status..."
if mongosh --quiet --eval "try { db.isMaster().setName } catch(e) { print('not_initialized') }" | grep -q "overleaf"; then
    echo "MongoDB replica set 'overleaf' is already initialized"
else
    echo "Initializing MongoDB replica set..."
    mongosh --quiet --eval '
        rs.initiate({
            _id: "overleaf",
            members: [
                {
                    _id: 0,
                    host: "127.0.0.1:27017"
                }
            ]
        })
    '
    
    # Wait for replica set to be ready
    echo "Waiting for replica set to be ready..."
    for i in {1..30}; do
        if mongosh --quiet --eval "db.isMaster().ismaster" | grep -q "true"; then
            echo "Replica set is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "ERROR: Replica set failed to become ready within 30 seconds"
            exit 1
        fi
        echo "Waiting for replica set... ($i/30)"
        sleep 2
    done
fi

# Create Overleaf database and initial configuration
echo "Setting up Overleaf database..."
mongosh --quiet sharelatex --eval '
    // Create initial collections if they do not exist
    if (!db.users.findOne()) {
        print("Creating initial database structure...");
        db.users.createIndex({"email": 1}, {"unique": true});
        db.projects.createIndex({"owner_ref": 1});
        db.docs.createIndex({"project_id": 1});
        print("Database structure created");
    } else {
        print("Database already exists");
    }
'

echo "MongoDB initialization completed successfully"

# Signal supervisor to start Overleaf
echo "Starting Overleaf service..."
supervisorctl start overleaf

echo "MongoDB initialization script finished"
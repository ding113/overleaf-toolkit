const express = require('express');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);
const app = express();
const PORT = 3000;

// Health check status
let healthStatus = {
    mongodb: false,
    redis: false,
    overleaf: false,
    lastCheck: null,
    uptime: process.uptime()
};

// Check MongoDB health
async function checkMongoDB() {
    try {
        const { stdout } = await execAsync('mongosh --quiet --eval "db.runCommand({ping: 1}).ok" 2>/dev/null');
        return stdout.trim() === '1';
    } catch (error) {
        console.error('MongoDB health check failed:', error.message);
        return false;
    }
}

// Check Redis health
async function checkRedis() {
    try {
        const { stdout } = await execAsync('redis-cli -h 127.0.0.1 -p 6379 ping 2>/dev/null');
        return stdout.trim() === 'PONG';
    } catch (error) {
        console.error('Redis health check failed:', error.message);
        return false;
    }
}

// Check Overleaf health
async function checkOverleaf() {
    try {
        const { stdout } = await execAsync('curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80/status 2>/dev/null');
        return stdout.trim() === '200';
    } catch (error) {
        // Overleaf might not be started yet, that's okay
        return false;
    }
}

// Update health status
async function updateHealthStatus() {
    try {
        const [mongodb, redis, overleaf] = await Promise.all([
            checkMongoDB(),
            checkRedis(),
            checkOverleaf()
        ]);

        healthStatus = {
            mongodb,
            redis,
            overleaf,
            lastCheck: new Date().toISOString(),
            uptime: process.uptime()
        };

        console.log(`Health check: MongoDB(${mongodb}), Redis(${redis}), Overleaf(${overleaf})`);
    } catch (error) {
        console.error('Health check update failed:', error.message);
    }
}

// Health endpoint for Dokploy
app.get('/health', (req, res) => {
    const isHealthy = healthStatus.mongodb && healthStatus.redis;
    
    if (isHealthy) {
        res.status(200).json({
            status: 'healthy',
            services: healthStatus,
            timestamp: new Date().toISOString()
        });
    } else {
        res.status(503).json({
            status: 'unhealthy',
            services: healthStatus,
            timestamp: new Date().toISOString()
        });
    }
});

// Detailed status endpoint
app.get('/status', (req, res) => {
    res.json({
        status: 'running',
        services: healthStatus,
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        timestamp: new Date().toISOString()
    });
});

// Simple ping endpoint
app.get('/ping', (req, res) => {
    res.json({ message: 'pong', timestamp: new Date().toISOString() });
});

// Start health monitoring
setInterval(updateHealthStatus, 10000); // Check every 10 seconds

// Initial health check
updateHealthStatus();

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Health check server running on port ${PORT}`);
    console.log('Available endpoints:');
    console.log('  GET /health  - Health check for Dokploy');
    console.log('  GET /status  - Detailed status information');
    console.log('  GET /ping    - Simple ping endpoint');
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('Health check server shutting down...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('Health check server shutting down...');
    process.exit(0);
});
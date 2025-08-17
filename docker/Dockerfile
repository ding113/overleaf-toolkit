# All-in-One Overleaf with MongoDB and Redis
FROM tuetenk0pp/sharelatex-full:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    MONGO_VERSION=6.0 \
    REDIS_VERSION=6.2 \
    NODE_VERSION=18

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # MongoDB dependencies
    wget \
    gnupg \
    lsb-release \
    # Redis dependencies
    build-essential \
    tcl \
    # Process management
    supervisor \
    # Health check tools
    curl \
    # Node.js for health check service
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install MongoDB 6.0
RUN wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add - \
    && echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list \
    && apt-get update \
    && apt-get install -y mongodb-org \
    && mkdir -p /data/mongo \
    && chown mongodb:mongodb /data/mongo \
    && rm -rf /var/lib/apt/lists/*

# Install Redis 6.2
RUN cd /tmp \
    && wget http://download.redis.io/releases/redis-6.2.13.tar.gz \
    && tar xzf redis-6.2.13.tar.gz \
    && cd redis-6.2.13 \
    && make \
    && make install \
    && mkdir -p /data/redis \
    && rm -rf /tmp/redis-6.2.13*

# Create data directories
RUN mkdir -p /data/mongo /data/redis /var/lib/overleaf /var/log/supervisor \
    && chown -R mongodb:mongodb /data/mongo \
    && chown -R redis:redis /data/redis \
    && chown -R sharelatex:sharelatex /var/lib/overleaf

# Copy configuration files and scripts
COPY scripts/ /app/scripts/
COPY config/ /app/config/

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Copy supervisor configuration to correct location
RUN cp /app/scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set up health check service
WORKDIR /app
RUN npm init -y && npm install express

# Expose ports
EXPOSE 80 3000

# Set entry point
CMD ["/app/scripts/entrypoint.sh"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1
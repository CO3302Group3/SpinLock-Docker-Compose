# Microservices Docker Compose Setup

This directory contains the Docker Compose configuration for running all microservices in the Smart Parking System using a secure **API Gateway pattern**.

## Architecture Overview

This microservices setup follows security best practices by:
- **Nginx Reverse Proxy**: Main entry point handling HTTP/HTTPS traffic (ports 80, 443, 8080)
- **API Gateway**: Centralized routing and authentication service
- **Internal Communication**: All microservices communicate internally via Docker network
- **Secure Infrastructure**: MQTT, Kafka, and other infrastructure services are internal-only
- **Direct Service Access**: Kafka UI exposed directly on port 8001 for monitoring

## Services Included

### Core Services
- **Nginx Gateway** - `nginx:alpine` - **Main entry point (Ports 80, 443, 8080)**
- **API Gateway** - `rav2001h/spinlock-api-gateway:latest` - **Routing and Auth (Internal)**
- **User Authentication Service** - `rav2001h/user-auth-microservice:latest` - Internal Only
- **Device Telemetry** - Handles IoT device data - Currently Disabled
- **Device Onboarding** - Manages device registration - Currently Disabled
- **GeoLocation** - Location-based services - Currently Disabled
- **Parking Slot** - Parking slot management - Currently Disabled
- **Health Monitoring** - Service health checks - Currently Disabled
- **Alert and Event Processing** - Event handling - Currently Disabled
- **Admin Management** - Administrative functions - Currently Disabled
- **Notification** - Notification services - Currently Disabled
- **Logging** - Centralized logging - Currently Disabled

### Infrastructure Services
- **MQTT Broker** - Eclipse Mosquitto for IoT communication - Internal Only
- **Kafka** - Event streaming platform (KRaft mode, no Zookeeper) - Internal Only
- **Kafka UI** - Web interface for Kafka management - **Direct Access (Port 8001)**

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- PowerShell (Windows) or Bash (Linux/Mac)

### Step 0: Environment Configuration
```powershell
# Copy environment template
copy .env.example .env

# Generate a secure JWT secret (optional)
.\manage.ps1 jwt-secret

# Edit .env file with your configuration
notepad .env
```

### Step 1: Build and Pull Images
```powershell
# Windows PowerShell
.\manage.ps1 build    # Build API Gateway
.\manage.ps1 pull     # Pull other images

# Or use Docker Compose directly
docker-compose build
docker-compose pull
```

### Step 2: Start Services

#### Production Mode
```powershell
# Windows PowerShell
.\manage.ps1 start

# Or use Docker Compose directly
docker-compose up -d
```

#### Development Mode (with additional services)
```powershell
# Windows PowerShell
.\manage.ps1 start-dev

# Or use Docker Compose directly
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### Step 3: Check Status
```powershell
# Windows PowerShell
.\manage.ps1 status

# Or use Docker Compose directly
docker-compose ps
```

## Nginx Gateway - Main Entry Point

**🔑 All web traffic goes through the Nginx reverse proxy at the following ports:**

- **HTTP**: `http://localhost` (port 80)
- **HTTPS**: `https://localhost` (port 443) 
- **Health Checks**: `http://localhost:8080` (internal monitoring)

### Nginx Gateway Features:
- **Reverse Proxy**: Routes traffic to API Gateway and other services
- **SSL/TLS Termination**: Handles HTTPS encryption
- **Security Headers**: Adds security headers to all responses
- **Rate Limiting**: Protects against abuse and DDoS
- **WebSocket Support**: Handles MQTT WebSocket connections
- **Health Monitoring**: Provides health check endpoints

### Available Routes through Nginx:

#### API Gateway Routes (via Nginx)
- `GET/POST /*` - All API requests routed to API Gateway
- `GET /health` - API Gateway health check
- `POST /auth/*` - Authentication endpoints

#### Infrastructure Routes (via Nginx)  
- `GET /mqtt/` - MQTT WebSocket connections
- `GET /mqtt-api/` - MQTT HTTP API (if configured)

## Direct Service Access

### Kafka UI - Direct Access
**🔍 Kafka monitoring and management:**
- **URL**: `http://localhost:8001`
- **Purpose**: Monitor Kafka cluster, topics, consumers, and messages
- **Features**: Topic management, consumer group monitoring, message browsing

## Service Access and Architecture

### External Access (Public)
| Service | Port | URL | Description |
|---------|------|-----|-------------|
| **Nginx Gateway** | **80** | **http://localhost** | **🌐 Main HTTP entry point** |
| **Nginx Gateway** | **443** | **https://localhost** | **🔒 Main HTTPS entry point** |
| **Nginx Health** | **8080** | **http://localhost:8080** | **⚕️ Health checks and monitoring** |
| **Kafka UI** | **8001** | **http://localhost:8001** | **📊 Kafka management interface** |

### Internal Services (Docker Network Only)
| Service | Internal Address | Description |
|---------|------------------|-------------|
| API Gateway | api-gateway:8000 | Routing and authentication |
| User Auth | user-auth-service:8000 | Authentication service |
| MQTT Broker | mqtt-broker:1883 | IoT messaging |
| MQTT WebSocket | mqtt-broker:9001 | Web MQTT (via nginx /mqtt/) |
| Kafka Broker | kafka:29092 | Event streaming (KRaft mode) |

### Currently Disabled Services
The following services are defined but commented out in docker-compose.yml:
- Device Telemetry (would be internal only)
- Device Onboarding (would be internal only)
- GeoLocation (would be internal only)
- Parking Slot (would be internal only)
- Health Monitoring (would be internal only)
- Alert Processing (would be internal only)
- Admin Management (would be internal only)
- Notification (would be internal only)  
- Logging (would be internal only)

**📝 Note**: When enabled, these services will be accessible through the Nginx Gateway and API Gateway routing.

## Testing the System

### Test Nginx Gateway
```powershell  
# Test main HTTP endpoint
Invoke-RestMethod -Uri "http://localhost" -Method GET

# Test HTTPS endpoint (if SSL configured)
Invoke-RestMethod -Uri "https://localhost" -Method GET

# Test health endpoint
Invoke-RestMethod -Uri "http://localhost:8080/health" -Method GET

# Test nginx status (internal network only)
curl http://localhost:8080/status
```

### Test Kafka UI
```powershell
# Open Kafka UI in browser or test endpoint
Invoke-RestMethod -Uri "http://localhost:8001" -Method GET
```

### Test API Gateway (through Nginx)
```powershell
# Test API Gateway health through Nginx
Invoke-RestMethod -Uri "http://localhost/health" -Method GET

# Test authentication endpoints
Invoke-RestMethod -Uri "http://localhost/auth/health" -Method GET
```

## Management Commands

### Using PowerShell Script (Windows)

```powershell
# Pull all images
.\manage.ps1 pull

# Generate JWT secret
.\manage.ps1 jwt-secret

# Start services
.\manage.ps1 start              # Production mode
.\manage.ps1 start-dev          # Development mode

# Stop services
.\manage.ps1 stop

# Restart services
.\manage.ps1 restart

# View logs
.\manage.ps1 logs               # All services
.\manage.ps1 logs user-auth-service  # Specific service

# Check status
.\manage.ps1 status

# Reset everything (careful!)
.\manage.ps1 reset

# Show help
.\manage.ps1 help
```

### Using Docker Compose Directly

```bash
# Pull images
docker-compose pull

# Start services
docker-compose up -d                                    # Production
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d  # Development

# Stop services
docker-compose down

# View logs
docker-compose logs -f
docker-compose logs -f user-auth-service

# Check status
docker-compose ps

# Remove everything including volumes
docker-compose down -v
```

## Kafka Configuration

### Event Streaming Topics

The system uses Kafka for event-driven communication between microservices. Common topics include:

- `device.telemetry` - Device sensor data
- `parking.events` - Parking slot status changes
- `user.events` - User registration/login events
- `alerts.critical` - Critical system alerts
- `notifications.queue` - Notification messages
- `audit.logs` - System audit events

### Kafka Management

**⚠️ Note**: Kafka UI is currently exposed on port 8080. In production, consider removing external access.

Access the Kafka UI at `http://localhost:8080` to:
- View topics and partitions
- Monitor message throughput
- Create/delete topics
- View consumer groups
- Browse messages

### Internal Kafka Communication

Services communicate with Kafka using the internal address:
```yaml
environment:
  - KAFKA_BOOTSTRAP_SERVERS=kafka:29092
```

**Important**: External Kafka access (port 9092) is disabled for security. Use docker exec to access Kafka CLI tools if needed:
```powershell
# Access Kafka CLI tools
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --list
```

## Configuration

### Environment Variables

The services can be configured using environment variables. Key configurations:

- `JWT_SECRET_KEY` - Secret key for JWT token generation (required)
- `JWT_ALGORITHM` - JWT algorithm (default: HS256)
- `JWT_EXPIRATION_HOURS` - Token expiration time (default: 24)
- `DATABASE_URL` - Database connection string
- `MQTT_BROKER_URL` - MQTT broker connection
- `KAFKA_BOOTSTRAP_SERVERS` - Kafka bootstrap servers
- `DEBUG` - Enable debug mode (development)
- `LOG_LEVEL` - Logging level

**Security Note**: Always use a strong, randomly generated JWT secret in production!

### Volume Mounts

- `user_auth_data` - User authentication data
- `logs_data` - Application logs
- `mqtt_data` - MQTT broker data
- `kafka_data` - Kafka broker data
- `zookeeper_data` - Zookeeper data
- `postgres_data` - PostgreSQL data (dev)
- `redis_data` - Redis data (dev)

## Security Architecture

### API Gateway Pattern Benefits

✅ **Single Entry Point**: All external traffic goes through port 8000  
✅ **Authentication**: Centralized JWT token validation  
✅ **Authorization**: Role-based access control  
✅ **Rate Limiting**: Protection against abuse  
✅ **Request/Response Logging**: Centralized audit trail  
✅ **Service Discovery**: Internal service routing  

### Security Implementation

1. **Network Isolation**: Microservices communicate only via internal Docker network
2. **No Direct Access**: Infrastructure services (MQTT, Kafka) not externally accessible
3. **Authentication Gateway**: All requests authenticated at the gateway level
4. **Secure Defaults**: Production-ready security configurations

### Production Security Checklist

- [ ] Generate strong JWT secrets (`.\manage.ps1 jwt-secret`)
- [ ] Remove Kafka UI external access (comment out port 8080)
- [ ] Configure HTTPS/TLS termination at the gateway
- [ ] Set up proper firewall rules
- [ ] Use secrets management (Docker secrets, Kubernetes secrets)
- [ ] Enable audit logging
- [ ] Configure rate limiting policies

## Network Configuration

All services run on the `microservices-network` bridge network with subnet `172.20.0.0/16`.

**Internal Service Communication Examples**:
- User Auth Service: `http://user-auth-service:8000`
- MQTT Broker: `mqtt://mqtt-broker:1883`
- Kafka: `kafka:29092`
- Zookeeper: `zookeeper:2181`

## Development vs Production

### Production Mode
- Minimal services
- Optimized for performance
- Uses production-ready configurations

### Development Mode
- Additional debugging services
- Database and cache services included
- Volume mounts for hot reloading
- Portainer for container management

## Troubleshooting

### Common Issues

1. **Port conflicts**: Check if ports are already in use
   ```powershell
   netstat -an | findstr ":8000"  # Check if API Gateway port is in use
   ```

2. **Missing images**: Run `.\manage.ps1 pull` to download images

3. **Service not starting**: Check logs with `.\manage.ps1 logs [service-name]`

4. **Network issues**: Restart Docker or use `.\manage.ps1 reset`

5. **Cannot access services**: Remember only API Gateway (port 8000) is externally accessible

### Health Checks

Check service health through the API Gateway:
```powershell
# Check API Gateway health
Invoke-RestMethod -Uri "http://localhost:8000/health"

# Check overall system status
Invoke-RestMethod -Uri "http://localhost:8000/status"
```

### Internal Service Debugging

To debug internal services, use docker exec:
```powershell
# Access service logs
docker logs user-auth-service

# Execute commands inside containers
docker exec -it user-auth-service /bin/bash

# Check internal network connectivity
docker exec -it api-gateway ping user-auth-service
```

### Logs

View logs for debugging:
```powershell
# All services
.\manage.ps1 logs

# Specific service
.\manage.ps1 logs user-auth-service

# Follow logs in real-time
.\manage.ps1 logs api-gateway
```

## Building Custom Images

For services not available on Docker Hub, you'll need to build them locally:

```bash
# Example for building a service
cd ../UserAuthenticationMicroservice
docker build -t user-auth-microservice:latest .

# Update the image tag in docker-compose.yml if needed
```

## Security Notes

## Security Notes

### Current Configuration
- **Nginx Gateway (Ports 80, 443, 8080)**: ✅ Secure reverse proxy entry point
- **Kafka UI (Port 8001)**: ⚠️ Direct access for monitoring - consider internal-only in production
- **All other services**: ✅ Internal only - secure

### Production Security Best Practices

1. **Remove Kafka UI external access**:
   ```yaml
   # Comment out in docker-compose.yml to make Kafka UI internal-only
   # ports:
   #   - "8001:8080"
   ```

2. **Use strong JWT secrets**:
   ```powershell
   .\manage.ps1 jwt-secret
   ```

3. **Configure HTTPS**: Use reverse proxy (nginx, traefik) with SSL certificates

4. **Environment Variables**: Never commit secrets to version control

5. **Network Security**: Use proper firewall rules and VPC configuration

6. **Monitoring**: Implement proper logging and monitoring solutions

### Default Configuration Warning
⚠️ **This configuration is optimized for development and local testing. For production deployment, additional security measures are required.**

## Quick Reference

### 🚀 **Start Everything**
```powershell
.\manage.ps1 start
```

### 🔍 **Check Status**
```powershell
.\manage.ps1 status
```

### 🧪 **Test All Services**
```powershell
.\manage.ps1 test
```

### 🌐 **Access Points**
- **Main API**: http://localhost or https://localhost
- **Kafka UI**: http://localhost:8001
- **Nginx Health**: http://localhost:8080/health

### 📊 **Monitor Services**
```powershell
.\manage.ps1 logs               # All services
.\manage.ps1 logs kafka-ui      # Specific service
docker-compose ps               # Quick status
```

## Contributing

1. Test changes locally first
2. Update documentation if needed
3. Ensure all services start successfully
4. Check health endpoints work correctly

## License

This configuration is part of the Smart Parking System microservices architecture.

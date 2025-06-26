# Microservices Docker Compose Setup

This directory contains the Docker Compose configuration for running all microservices in the Smart Parking System.

## Services Included

### Core Services
- **User Authentication Service** - `rav2001h/user-auth-microservice:latest` (from Docker Hub)
- **API Gateway** - Routes requests to appropriate microservices
- **Device Telemetry** - Handles IoT device data
- **Device Onboarding** - Manages device registration
- **GeoLocation** - Location-based services
- **Parking Slot** - Parking slot management
- **Health Monitoring** - Service health checks
- **Alert and Event Processing** - Event handling
- **Admin Management** - Administrative functions
- **Notification** - Notification services
- **Logging** - Centralized logging

### Infrastructure Services
- **MQTT Broker** - Eclipse Mosquitto for IoT communication
- **Kafka** - Event streaming and messaging platform
- **Zookeeper** - Kafka coordination service
- **Kafka UI** - Web interface for Kafka management
- **PostgreSQL** - Database (development mode)
- **Redis** - Caching (development mode)
- **Portainer** - Container management UI (development mode)

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

## API Gateway Endpoints

The API Gateway exposes external endpoints and routes them to appropriate microservices:

### Authentication Routes (via API Gateway)
- `POST /auth/register` - Register new user
- `POST /auth/login` - User login
- `POST /auth/validate` - Validate JWT token
- `GET /auth/health` - Auth service health check

### Gateway Management
- `GET /health` - Gateway health check
- `GET /status` - Overall system status
- `GET /` - Service information and available endpoints

### Testing the API Gateway
```powershell
# Test all endpoints
cd ../APIGateway
.\test_gateway.ps1

# Or using Python
python test_gateway.py
```

## Service Endpoints

| Service | Port | Health Check | Description |
|---------|------|--------------|-------------|
| API Gateway | 8000 | http://localhost:8000 | Main entry point |
| User Auth | 8001 | http://localhost:8001/health | Authentication service |
| Device Telemetry | 8002 | http://localhost:8002 | IoT data handling |
| Device Onboarding | 8003 | http://localhost:8003 | Device registration |
| GeoLocation | 8004 | http://localhost:8004 | Location services |
| Parking Slot | 8005 | http://localhost:8005 | Slot management |
| Health Monitoring | 8006 | http://localhost:8006 | Service monitoring |
| Alert Processing | 8007 | http://localhost:8007 | Event processing |
| Admin Management | 8008 | http://localhost:8008 | Admin functions |
| Notification | 8009 | http://localhost:8009 | Notifications |
| Logging | 8010 | http://localhost:8010 | Log aggregation |
| MQTT Broker | 1883 | mqtt://localhost:1883 | IoT messaging |
| MQTT WebSocket | 9001 | ws://localhost:9001 | Web MQTT |
| Kafka Broker | 9092 | localhost:9092 | Event streaming |
| Kafka UI | 8080 | http://localhost:8080 | Kafka management |
| Zookeeper | 2181 | localhost:2181 | Kafka coordination |
| Portainer (dev) | 9000 | http://localhost:9000 | Container UI |
| PostgreSQL (dev) | 5432 | localhost:5432 | Database |
| Redis (dev) | 6379 | localhost:6379 | Cache |

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

Access the Kafka UI at `http://localhost:8080` to:
- View topics and partitions
- Monitor message throughput
- Create/delete topics
- View consumer groups
- Browse messages

### Environment Variables for Kafka

Services that use Kafka should include:
```yaml
environment:
  - KAFKA_BOOTSTRAP_SERVERS=kafka:29092
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

## Network Configuration

All services run on the `microservices-network` bridge network with subnet `172.20.0.0/16`.

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
2. **Missing images**: Run `.\manage.ps1 pull` to download images
3. **Service not starting**: Check logs with `.\manage.ps1 logs [service-name]`
4. **Network issues**: Restart Docker or use `.\manage.ps1 reset`

### Health Checks

All services include health checks. If a service is unhealthy:
1. Check the logs
2. Verify environment variables
3. Ensure dependencies are running

### Logs

View logs for debugging:
```powershell
# All services
.\manage.ps1 logs

# Specific service
.\manage.ps1 logs user-auth-service
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

- Default configuration is for development
- Change default passwords in production
- Use proper secrets management
- Configure firewall rules appropriately
- Use HTTPS in production

## Contributing

1. Test changes locally first
2. Update documentation if needed
3. Ensure all services start successfully
4. Check health endpoints work correctly

## License

This configuration is part of the Smart Parking System microservices architecture.

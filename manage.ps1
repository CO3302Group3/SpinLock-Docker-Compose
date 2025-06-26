# Microservices Docker Compose Management Script for Windows PowerShell

param(
    [Parameter(Position=0)]
    [string]$Command = "help",
    [Parameter(Position=1)]
    [string]$Service = "",
    [Parameter(Position=2)]
    [string]$Environment = "production"
)

# Colors for output
$Colors = @{
    Info = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
}

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Info
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Success
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Warning
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Error
}

function Pull-Images {
    Write-Status "Pulling Docker images..."
    
    try {
        # Pull the API Gateway image
        docker pull rav2001h/spinlock-api-gateway:latest
        
        # Pull the user authentication microservice from Docker Hub
        docker pull rav2001h/user-auth-microservice:latest
        
        # Pull Nginx proxy server
        docker pull nginx:alpine
        
        # Pull other standard images
        docker pull eclipse-mosquitto:2.0
        docker pull postgres:15-alpine
        docker pull redis:7-alpine
        docker pull portainer/portainer-ce:latest
        docker pull confluentinc/cp-kafka:7.6.0  # Latest KRaft-enabled Kafka (no Zookeeper needed)
        docker pull provectuslabs/kafka-ui:latest
        
        Write-Success "All available images pulled successfully!"
        Write-Warning "Note: Custom microservice images need to be built locally"
    }
    catch {
        Write-Error "Failed to pull images: $($_.Exception.Message)"
    }
}

function Start-Services {
    param([string]$EnvType = "production")
    
    Write-Status "Starting microservices in $EnvType mode..."
    
    # Check if .env file exists, if not create from example
    if (-not (Test-Path ".env")) {
        if (Test-Path ".env.example") {
            Write-Warning ".env file not found, creating from .env.example"
            Copy-Item ".env.example" ".env"
            Write-Status "Please review and update the .env file with your configuration"
        }
    }
    
    try {
        if ($EnvType -eq "development") {
            docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
        } else {
            docker-compose up -d
        }
        
        Write-Success "Services started successfully!"
        Write-Status "Checking service health..."
        Start-Sleep -Seconds 10
        docker-compose ps
    }
    catch {
        Write-Error "Failed to start services: $($_.Exception.Message)"
    }
}

function Stop-Services {
    Write-Status "Stopping all services..."
    
    try {
        docker-compose down
        Write-Success "All services stopped!"
    }
    catch {
        Write-Error "Failed to stop services: $($_.Exception.Message)"
    }
}

function Show-Logs {
    param([string]$ServiceName = "")
    
    try {
        if ([string]::IsNullOrEmpty($ServiceName)) {
            Write-Status "Showing logs for all services..."
            docker-compose logs -f
        } else {
            Write-Status "Showing logs for $ServiceName..."
            docker-compose logs -f $ServiceName
        }
    }
    catch {
        Write-Error "Failed to show logs: $($_.Exception.Message)"
    }
}

function Show-Status {
    Write-Status "Service Status:"
    docker-compose ps
    
    Write-Host ""
    Write-Status "Service Health Checks and Access Points:"
    Write-Host "Nginx Gateway (Main Entry Point):" -ForegroundColor Green
    Write-Host "  HTTP:  http://localhost" -ForegroundColor Green
    Write-Host "  HTTPS: https://localhost" -ForegroundColor Green
    Write-Host "  Health: http://localhost:8080/health" -ForegroundColor Green
    Write-Host "  Kafka UI: http://localhost/kafka-ui/ or https://localhost/kafka-ui/" -ForegroundColor Green
    Write-Host ""
    Write-Status "Internal Services (Not Externally Accessible):"
    Write-Host "API Gateway: Internal only (api-gateway:8000)" -ForegroundColor Yellow
    Write-Host "User Auth Service: Internal only (user-auth-service:8000)" -ForegroundColor Yellow
    Write-Host "MQTT Broker: Internal only (mqtt-broker:1883)" -ForegroundColor Yellow
    Write-Host "Kafka Broker: Internal only (kafka:29092)" -ForegroundColor Yellow
    Write-Host "Kafka UI: Internal only (kafka-ui:8080)" -ForegroundColor Yellow
    Write-Host "Zookeeper: Internal only (zookeeper:2181)" -ForegroundColor Yellow
    Write-Host ""
    Write-Status "Note: All microservices are accessible through Nginx proxy at ports 80 (HTTP) and 443 (HTTPS)"
    Write-Host ""
    Write-Status "Infrastructure (KRaft Mode - No Zookeeper):"
    Write-Host "Kafka Broker: Internal only (kafka:29092) - KRaft enabled" -ForegroundColor Cyan
    Write-Host "MQTT Broker: Internal only (mqtt-broker:1883) + WebSocket (9001)" -ForegroundColor Cyan
}

function Build-Images {
    Write-Status "Building custom microservice images..."
    
    try {
        # Build API Gateway
        Write-Status "Building API Gateway..."
        Set-Location "../APIGateway"
        docker build -t api-gateway:latest .
        Set-Location "../SpinLock"
        
        Write-Success "API Gateway built successfully!"
        Write-Warning "Other microservice images need to be built individually"
        Write-Status "Build process completed"
    }
    catch {
        Write-Error "Failed to build images: $($_.Exception.Message)"
        Set-Location "../SpinLock"
    }
}

function New-JwtSecret {
    Write-Status "Generating new JWT secret..."
    
    # Generate a cryptographically secure random string
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
    $rng.GetBytes($bytes)
    $secret = [System.Convert]::ToBase64String($bytes)
    
    Write-Host "Generated JWT Secret: $secret" -ForegroundColor Green
    Write-Warning "Save this secret securely and update your .env file"
    Write-Status "You can also add this to your .env file:"
    Write-Host "JWT_SECRET_KEY=$secret" -ForegroundColor Cyan
}

function Reset-All {
    Write-Warning "This will stop all services and remove volumes!"
    $response = Read-Host "Are you sure? (y/N)"
    
    if ($response -match "^[Yy]$") {
        Write-Status "Stopping services and removing volumes..."
        try {
            docker-compose down -v
            docker system prune -f
            Write-Success "Reset completed!"
        }
        catch {
            Write-Error "Failed to reset: $($_.Exception.Message)"
        }
    } else {
        Write-Status "Reset cancelled"
    }
}

function Test-Nginx {
    Write-Status "Testing Nginx configuration..."
    
    try {
        # Test configuration syntax
        $result = docker-compose exec nginx nginx -t 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Nginx configuration is valid"
        } else {
            Write-Error "Nginx configuration has errors: $result"
        }
        
        # Test HTTP endpoint
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080/health" -TimeoutSec 5 -UseBasicParsing
            Write-Success "Nginx health check passed (HTTP $($response.StatusCode))"
        }
        catch {
            Write-Warning "Nginx health check failed: $($_.Exception.Message)"
        }
        
        # Show Nginx status
        Write-Status "Nginx container status:"
        docker-compose ps nginx
    }
    catch {
        Write-Error "Failed to test Nginx: $($_.Exception.Message)"
    }
}

function Restart-Nginx {
    Write-Status "Restarting Nginx service..."
    
    try {
        docker-compose restart nginx
        Write-Success "Nginx restarted successfully!"
        
        # Wait a moment and test
        Start-Sleep -Seconds 5
        Test-Nginx
    }
    catch {
        Write-Error "Failed to restart Nginx: $($_.Exception.Message)"
    }
}

function Show-Help {
    Write-Status "Microservices Docker Compose Management Script"
    Write-Host ""
    Write-Host "Usage: .\manage.ps1 [COMMAND] [SERVICE] [ENVIRONMENT]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Green
    Write-Host "  help          Show this help message" -ForegroundColor Gray
    Write-Host "  build         Build all services" -ForegroundColor Gray
    Write-Host "  pull          Pull all Docker images" -ForegroundColor Gray
    Write-Host "  start         Start all services" -ForegroundColor Gray
    Write-Host "  start-dev     Start services in development mode" -ForegroundColor Gray
    Write-Host "  stop          Stop all services" -ForegroundColor Gray
    Write-Host "  restart       Restart all services" -ForegroundColor Gray
    Write-Host "  status        Show status of all services" -ForegroundColor Gray
    Write-Host "  logs          Show logs for all services" -ForegroundColor Gray
    Write-Host "  clean         Clean up containers and networks" -ForegroundColor Gray
    Write-Host "  reset         Reset everything (clean + remove volumes)" -ForegroundColor Gray
    Write-Host "  jwt-secret    Generate a new JWT secret key" -ForegroundColor Gray
    Write-Host "  ssl-generate  Generate SSL certificates for HTTPS" -ForegroundColor Gray
    Write-Host "  kafka-cluster-id  Generate new Kafka cluster ID for KRaft" -ForegroundColor Gray
    Write-Host "  format-kafka  Format Kafka storage for KRaft mode" -ForegroundColor Gray
    Write-Host "  kafka-cluster-id  Generate a new Kafka Cluster ID" -ForegroundColor Gray
    Write-Host "  format-kafka  Format Kafka storage with new Cluster ID" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  .\manage.ps1 start" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 logs api-gateway" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 ssl-generate" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 jwt-secret" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Services Access:" -ForegroundColor Green
    Write-Host "• Main API: http://localhost or https://localhost" -ForegroundColor Gray
    Write-Host "• API Documentation: http://localhost/docs" -ForegroundColor Gray
    Write-Host "• Kafka UI: http://localhost/kafka-ui/" -ForegroundColor Gray
    Write-Host "• MQTT WebSocket: ws://localhost/mqtt/" -ForegroundColor Gray
    Write-Host "• MQTT HTTP API: http://localhost/mqtt-api/" -ForegroundColor Gray
    Write-Host "• SSL/TLS encryption available via HTTPS (port 443)" -ForegroundColor Gray
}

function Generate-SSLCertificates {
    Write-Status "Generating SSL certificates for HTTPS..."
    
    # Create SSL directory
    if (-not (Test-Path "ssl")) {
        New-Item -ItemType Directory -Path "ssl" -Force
        Write-Success "Created SSL directory"
    }

    try {
        # Try using OpenSSL first
        $null = Get-Command openssl -ErrorAction Stop
        Write-Status "Using OpenSSL to generate certificates..."
        
        # Generate private key
        & openssl genrsa -out ssl/nginx.key 2048
        
        # Generate certificate signing request and self-signed certificate
        & openssl req -new -x509 -key ssl/nginx.key -out ssl/nginx.crt -days 365 -subj "/C=US/ST=State/L=City/O=SpinLock/OU=Microservices/CN=localhost"
        
        Write-Success "SSL certificates generated successfully!"
        Write-Host "Certificate: ssl/nginx.crt" -ForegroundColor Cyan
        Write-Host "Private Key: ssl/nginx.key" -ForegroundColor Cyan
        
    } catch {
        Write-Warning "OpenSSL not found. Using Docker alternative..."
        
        try {
            Write-Status "Generating certificates using Docker..."
            docker run --rm -v "${PWD}/ssl:/ssl" alpine/openssl genrsa -out /ssl/nginx.key 2048
            docker run --rm -v "${PWD}/ssl:/ssl" alpine/openssl req -new -x509 -key /ssl/nginx.key -out /ssl/nginx.crt -days 365 -subj "/C=US/ST=State/L=City/O=SpinLock/OU=Microservices/CN=localhost"
            
            Write-Success "SSL certificates generated using Docker!"
            Write-Host "Certificate: ssl/nginx.crt" -ForegroundColor Cyan
            Write-Host "Private Key: ssl/nginx.key" -ForegroundColor Cyan
            
        } catch {
            Write-Error "Failed to generate SSL certificates. Please install OpenSSL or ensure Docker is running."
            Write-Host "Manual installation options:" -ForegroundColor Yellow
            Write-Host "1. Install OpenSSL: choco install openssl" -ForegroundColor Gray
            Write-Host "2. Use WSL: wsl -e openssl ..." -ForegroundColor Gray
            return $false
        }
    }
    
    return $true
}

function Clean-Services {
    Write-Status "Cleaning up containers and networks..."
    
    try {
        docker-compose down --remove-orphans
        docker system prune -f --volumes
        Write-Success "Cleanup completed!"
    }
    catch {
        Write-Error "Failed to clean services: $($_.Exception.Message)"
    }
}

function Generate-KafkaClusterID {
    Write-Status "Generating new Kafka Cluster ID for KRaft mode..."
    
    # Generate a proper Base64 UUID for Kafka KRaft cluster ID
    $guid = [System.Guid]::NewGuid()
    $bytes = $guid.ToByteArray()
    $clusterId = [System.Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_').Substring(0, 22)
    
    Write-Host "Generated Kafka Cluster ID: $clusterId" -ForegroundColor Green
    Write-Warning "Update your docker-compose.yml with this cluster ID:"
    Write-Host "CLUSTER_ID: '$clusterId'" -ForegroundColor Cyan
    Write-Host ""
    Write-Status "Or you can use the kafka-storage tool to format the log directories:"
    Write-Host "docker run --rm -v kafka_data:/var/lib/kafka/data confluentinc/cp-kafka:7.6.0 kafka-storage format -t $clusterId -c /etc/kafka/server.properties" -ForegroundColor Yellow
    
    return $clusterId
}

function Format-KafkaStorage {
    Write-Status "Formatting Kafka storage for KRaft mode..."
    Write-Warning "This will clear all existing Kafka data!"
    
    $response = Read-Host "Continue with formatting? (y/N)"
    if ($response -match "^[Yy]$") {
        try {
            # Generate cluster ID
            $clusterId = Generate-KafkaClusterID
            
            Write-Status "Stopping Kafka if running..."
            docker-compose stop kafka 2>$null
            
            Write-Status "Removing existing Kafka data volume..."
            docker volume rm spinlock-docker-compose_kafka_data 2>$null
            
            Write-Status "Creating and formatting new Kafka storage..."
            docker run --rm -v kafka_data:/var/lib/kafka/data confluentinc/cp-kafka:7.6.0 `
                kafka-storage format -t $clusterId -c /etc/kafka/server.properties
            
            Write-Success "Kafka storage formatted successfully!"
            Write-Status "You can now start Kafka with: .\manage.ps1 start"
            
        } catch {
            Write-Error "Failed to format Kafka storage: $($_.Exception.Message)"
        }
    } else {
        Write-Status "Kafka storage formatting cancelled"
    }
}

# Main script logic
switch ($Command.ToLower()) {
    "pull" {
        Pull-Images
    }
    "start" {
        Start-Services $Environment
    }
    "start-dev" {
        Start-Services "development"
    }
    "stop" {
        Stop-Services
    }
    "restart" {
        Stop-Services
        Start-Services $Environment
    }
    "logs" {
        Show-Logs $Service
    }
    "status" {
        Show-Status
    }
    "build" {
        Build-Images
    }
    "test-nginx" {
        Test-Nginx
    }
    "restart-nginx" {
        Restart-Nginx
    }
    "jwt-secret" {
        New-JwtSecret
    }
    "clean" {
        Clean-Services
    }
    "reset" {
        Reset-All
    }
    "ssl-generate" {
        Generate-SSLCertificates
    }
    "kafka-cluster-id" {
        Generate-KafkaClusterID
    }
    "format-kafka" {
        Format-KafkaStorage
    }
    default {
        Show-Help
    }
}

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
        # Pull the user authentication microservice from Docker Hub
        docker pull rav2001h/user-auth-microservice:latest
        
        # Pull other standard images
        docker pull eclipse-mosquitto:2.0
        docker pull postgres:15-alpine
        docker pull redis:7-alpine
        docker pull portainer/portainer-ce:latest
        docker pull confluentinc/cp-zookeeper:7.4.0
        docker pull confluentinc/cp-kafka:7.4.0
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

function Start-SpecificServices {
    param(
        [string[]]$ServiceNames,
        [string]$EnvType = "production"
    )
    
    Write-Status "Starting specific services: $($ServiceNames -join ', ') in $EnvType mode..."
    
    # Check if .env file exists, if not create from example
    if (-not (Test-Path ".env")) {
        if (Test-Path ".env.example") {
            Write-Warning ".env file not found, creating from .env.example"
            Copy-Item ".env.example" ".env"
            Write-Status "Please review and update the .env file with your configuration"
        }
    }
    
    try {
        $serviceArgs = $ServiceNames -join " "
        
        if ($EnvType -eq "development") {
            docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d $serviceArgs
        } else {
            docker-compose up -d $serviceArgs
        }
        
        Write-Success "Specific services started successfully!"
        Write-Status "Checking service health..."
        Start-Sleep -Seconds 10
        docker-compose ps
    }
    catch {
        Write-Error "Failed to start specific services: $($_.Exception.Message)"
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
    Write-Status "Service Health Checks:"
    Write-Host "User Auth Service: http://localhost:8001/health" -ForegroundColor White
    Write-Host "API Gateway: http://localhost:8000" -ForegroundColor White
    Write-Host "MQTT Broker: mqtt://localhost:1883" -ForegroundColor White
    Write-Host "Kafka Broker: localhost:9092" -ForegroundColor White
    Write-Host "Kafka UI: http://localhost:8080" -ForegroundColor White
    Write-Host "Zookeeper: localhost:2181" -ForegroundColor White
    Write-Host "Portainer (dev): http://localhost:9000" -ForegroundColor White
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

function Show-Help {
    Write-Host "Microservices Management Script for Windows PowerShell" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\manage.ps1 [command] [service] [environment]" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor White
    Write-Host "  pull           Pull all Docker images" -ForegroundColor Gray
    Write-Host "  start          Start services in production mode" -ForegroundColor Gray
    Write-Host "  start-dev      Start services in development mode" -ForegroundColor Gray
    Write-Host "  start-minimal  Start only gateway and user auth services" -ForegroundColor Gray
    Write-Host "  stop           Stop all services" -ForegroundColor Gray
    Write-Host "  restart        Restart services" -ForegroundColor Gray
    Write-Host "  logs [service] View logs (optionally for specific service)" -ForegroundColor Gray
    Write-Host "  status         Show service status and health endpoints" -ForegroundColor Gray
    Write-Host "  build          Build custom microservice images" -ForegroundColor Gray
    Write-Host "  jwt-secret     Generate a new JWT secret key" -ForegroundColor Gray
    Write-Host "  reset          Stop services and remove all volumes" -ForegroundColor Gray
    Write-Host "  help           Show this help message" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\manage.ps1 pull                              # Pull all images" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 start                             # Start in production mode" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 start-dev                         # Start in development mode" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 logs user-auth-service            # View logs for user auth service" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 status                            # Check service status" -ForegroundColor Gray
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
    "start-minimal" {
        Start-SpecificServices @("api-gateway", "user-auth-service") $Environment
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
    "jwt-secret" {
        New-JwtSecret
    }
    "reset" {
        Reset-All
    }
    default {
        Show-Help
    }
}

#!/bin/bash

# Microservices Docker Compose Management Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to pull all images
pull_images() {
    print_status "Pulling Docker images..."
    
    # Pull the user authentication microservice from Docker Hub
    docker pull rav2001h/user-auth-microservice:latest
    
    # Pull other standard images
    docker pull eclipse-mosquitto:2.0
    docker pull postgres:15-alpine
    docker pull redis:7-alpine
    docker pull portainer/portainer-ce:latest
    
    print_success "All available images pulled successfully!"
    print_warning "Note: Custom microservice images need to be built locally"
}

# Function to start services
start_services() {
    local env_type=${1:-production}
    
    print_status "Starting microservices in $env_type mode..."
    
    if [ "$env_type" = "development" ]; then
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
    else
        docker-compose up -d
    fi
    
    print_success "Services started successfully!"
    print_status "Checking service health..."
    sleep 10
    docker-compose ps
}

# Function to stop services
stop_services() {
    print_status "Stopping all services..."
    docker-compose down
    print_success "All services stopped!"
}

# Function to view logs
view_logs() {
    local service=${1:-}
    
    if [ -z "$service" ]; then
        print_status "Showing logs for all services..."
        docker-compose logs -f
    else
        print_status "Showing logs for $service..."
        docker-compose logs -f "$service"
    fi
}

# Function to show service status
show_status() {
    print_status "Service Status:"
    docker-compose ps
    
    print_status "\nService Health Checks:"
    echo "User Auth Service: http://localhost:8001/health"
    echo "API Gateway: http://localhost:8000"
    echo "MQTT Broker: mqtt://localhost:1883"
    echo "Portainer (dev): http://localhost:9000"
}

# Function to build custom images
build_images() {
    print_status "Building custom microservice images..."
    
    # Note: This would need to be customized based on actual Dockerfiles
    print_warning "Custom image building not implemented yet"
    print_status "You need to build individual microservice images first"
}

# Function to reset everything
reset_all() {
    print_warning "This will stop all services and remove volumes!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Stopping services and removing volumes..."
        docker-compose down -v
        docker system prune -f
        print_success "Reset completed!"
    else
        print_status "Reset cancelled"
    fi
}

# Main script logic
case "${1:-help}" in
    "pull")
        pull_images
        ;;
    "start")
        start_services "${2:-production}"
        ;;
    "start-dev")
        start_services "development"
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        stop_services
        start_services "${2:-production}"
        ;;
    "logs")
        view_logs "$2"
        ;;
    "status")
        show_status
        ;;
    "build")
        build_images
        ;;
    "reset")
        reset_all
        ;;
    "help"|*)
        echo "Microservices Management Script"
        echo ""
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  pull           Pull all Docker images"
        echo "  start          Start services in production mode"
        echo "  start-dev      Start services in development mode"
        echo "  stop           Stop all services"
        echo "  restart        Restart services"
        echo "  logs [service] View logs (optionally for specific service)"
        echo "  status         Show service status and health endpoints"
        echo "  build          Build custom microservice images"
        echo "  reset          Stop services and remove all volumes"
        echo "  help           Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 pull                    # Pull all images"
        echo "  $0 start                   # Start in production mode"
        echo "  $0 start-dev               # Start in development mode"
        echo "  $0 logs user-auth-service  # View logs for user auth service"
        echo "  $0 status                  # Check service status"
        ;;
esac

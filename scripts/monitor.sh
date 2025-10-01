#!/bin/bash

# Xiaohongshu MCP Service Monitor Script
# Usage: ./monitor.sh [check|restart|status|logs]

SERVICE_NAME="xiaohongshu-mcp"
HEALTH_URL="http://localhost:18060/health"
LOG_FILE="/var/log/xiaohongshu-mcp-monitor.log"
COMPOSE_FILE="/opt/xiaohongshu-mcp/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check service health
check_health() {
    log "Checking service health..."
    
    # Check if container is running
    if ! docker ps | grep -q "$SERVICE_NAME"; then
        log "ERROR: Container $SERVICE_NAME is not running"
        return 1
    fi
    
    # Check HTTP health endpoint
    if curl -f -s "$HEALTH_URL" > /dev/null; then
        log "SUCCESS: Service is healthy"
        return 0
    else
        log "ERROR: Health check failed"
        return 1
    fi
}

# Restart service
restart_service() {
    log "Restarting service..."
    cd "$(dirname "$COMPOSE_FILE")"
    
    docker compose down
    sleep 5
    docker compose up -d
    
    # Wait for service to be ready
    sleep 30
    
    if check_health; then
        log "SUCCESS: Service restarted successfully"
        return 0
    else
        log "ERROR: Service restart failed"
        return 1
    fi
}

# Show service status
show_status() {
    echo -e "${YELLOW}=== Xiaohongshu MCP Service Status ===${NC}"
    
    # Container status
    echo -e "\n${GREEN}Container Status:${NC}"
    docker ps -f name="$SERVICE_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Resource usage
    echo -e "\n${GREEN}Resource Usage:${NC}"
    docker stats "$SERVICE_NAME" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    
    # Health check
    echo -e "\n${GREEN}Health Check:${NC}"
    if check_health; then
        echo -e "${GREEN}✓ Service is healthy${NC}"
    else
        echo -e "${RED}✗ Service is unhealthy${NC}"
    fi
    
    # Recent logs
    echo -e "\n${GREEN}Recent Logs (last 10 lines):${NC}"
    docker logs --tail 10 "$SERVICE_NAME"
}

# Show logs
show_logs() {
    local lines=${1:-50}
    echo -e "${YELLOW}=== Last $lines lines of logs ===${NC}"
    docker logs --tail "$lines" -f "$SERVICE_NAME"
}

# Auto-restart if unhealthy
auto_monitor() {
    log "Starting auto-monitor mode..."
    
    while true; do
        if ! check_health; then
            log "Service unhealthy, attempting restart..."
            restart_service
            
            # Send alert (optional - configure your notification method)
            # send_alert "Xiaohongshu MCP service was restarted due to health check failure"
        fi
        
        sleep 300  # Check every 5 minutes
    done
}

# Send alert (customize this function based on your notification system)
send_alert() {
    local message="$1"
    log "ALERT: $message"
    
    # Example: Send to webhook
    # curl -X POST -H 'Content-type: application/json' \
    #   --data "{\"text\":\"$message\"}" \
    #   YOUR_WEBHOOK_URL
    
    # Example: Send email
    # echo "$message" | mail -s "Xiaohongshu MCP Alert" admin@yourdomain.com
}

# Backup data
backup_data() {
    local backup_dir="/backup/xiaohongshu-mcp"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/backup_$timestamp.tar.gz"
    
    log "Creating backup..."
    
    mkdir -p "$backup_dir"
    
    # Stop service temporarily for consistent backup
    docker compose -f "$COMPOSE_FILE" stop
    
    # Create backup
    tar -czf "$backup_file" \
        -C "$(dirname "$COMPOSE_FILE")" \
        data/ images/ docker-compose.yml
    
    # Restart service
    docker compose -f "$COMPOSE_FILE" start
    
    log "Backup created: $backup_file"
    
    # Clean old backups (keep last 7 days)
    find "$backup_dir" -name "backup_*.tar.gz" -mtime +7 -delete
}

# Update service
update_service() {
    log "Updating service..."
    
    cd "$(dirname "$COMPOSE_FILE")"
    
    # Pull latest image
    docker compose pull
    
    # Restart with new image
    docker compose up -d
    
    # Wait and check
    sleep 30
    if check_health; then
        log "SUCCESS: Service updated successfully"
    else
        log "ERROR: Service update failed"
        return 1
    fi
}

# Main script logic
case "$1" in
    "check")
        check_health
        ;;
    "restart")
        restart_service
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs "$2"
        ;;
    "monitor")
        auto_monitor
        ;;
    "backup")
        backup_data
        ;;
    "update")
        update_service
        ;;
    *)
        echo "Usage: $0 {check|restart|status|logs [lines]|monitor|backup|update}"
        echo ""
        echo "Commands:"
        echo "  check    - Check service health"
        echo "  restart  - Restart the service"
        echo "  status   - Show service status and stats"
        echo "  logs     - Show service logs (default: 50 lines)"
        echo "  monitor  - Start auto-monitoring (restart if unhealthy)"
        echo "  backup   - Create data backup"
        echo "  update   - Update service to latest version"
        exit 1
        ;;
esac
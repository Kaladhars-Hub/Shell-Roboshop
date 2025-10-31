#!/bin/bash

# =============================================================================
# BACKEND SERVICES DEPLOYMENT SCRIPT
# Use this on Instance 1: MongoDB + Redis + RabbitMQ
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
INFRA_DIR="$PARENT_DIR/infrastructure"

# Colors for output
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOG_FILE="/var/log/Shell-Roboshop/backend-deployment.log"

echo "===============================================" | tee -a "$LOG_FILE"
echo "🚀 STARTING BACKEND SERVICES DEPLOYMENT" | tee -a "$LOG_FILE"
echo "===============================================" | tee -a "$LOG_FILE"
echo "Deployment started at: $(date)" | tee -a "$LOG_FILE"

VALIDATE(){
    local exit_code=$1
    local action_name=$2
    
    if [ "$exit_code" -ne 0 ]; then
        echo -e "$action_name ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "$action_name ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
    fi
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${R}ERROR: Run with sudo${N}" | tee -a "$LOG_FILE"
    exit 1
fi

# Create log directory
mkdir -p "/var/log/Shell-Roboshop"

echo -e "\n${Y}=== DEPLOYING MONGODB ===${N}" | tee -a "$LOG_FILE"
"$INFRA_DIR/mongodb.sh"
VALIDATE $? "MongoDB deployment"

echo -e "\n${Y}=== DEPLOYING REDIS ===${N}" | tee -a "$LOG_FILE" 
"$INFRA_DIR/redis.sh"
VALIDATE $? "Redis deployment"

echo -e "\n${Y}=== DEPLOYING RABBITMQ ===${N}" | tee -a "$LOG_FILE"
"$INFRA_DIR/rabbitmq.sh"
VALIDATE $? "RabbitMQ deployment"

echo -e "\n${Y}=== VERIFYING BACKEND SERVICES ===${N}" | tee -a "$LOG_FILE"

# Verify services are running
services=("mongod" "redis" "rabbitmq-server")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo -e "✅ $service ... ${G}RUNNING${N}" | tee -a "$LOG_FILE"
    else
        echo -e "❌ $service ... ${R}NOT RUNNING${N}" | tee -a "$LOG_FILE"
    fi
done

echo -e "\n${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${G}✅ BACKEND SERVICES DEPLOYMENT COMPLETED${N}" | tee -a "$LOG_FILE"
echo -e "${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${Y}📊 MongoDB: 27017${N}" | tee -a "$LOG_FILE"
echo -e "${Y}📊 Redis: 6379${N}" | tee -a "$LOG_FILE" 
echo -e "${Y}📊 RabbitMQ: 5672${N}" | tee -a "$LOG_FILE"
echo "Completed at: $(date)" | tee -a "$LOG_FILE"
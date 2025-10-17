#!/bin/bash

# =============================================================================
# ROBOSHOP RABBITMQ INSTALLATION SCRIPT
# =============================================================================
# This script installs and configures RabbitMQ message broker
# RabbitMQ handles message queuing between services
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_status() {
    if [ $? -eq 0 ]; then
        print_message "$1 - SUCCESS"
    else
        print_error "$1 - FAILED"
        exit 1
    fi
}

if [ $(id -u) -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

print_message "Starting RabbitMQ Installation..."
echo "=============================================="

# STEP 1: Install Erlang (RabbitMQ dependency)
print_message "Step 1: Installing Erlang (RabbitMQ dependency)..."
curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | bash
check_status "Erlang repository setup"

# STEP 2: Install RabbitMQ repository
print_message "Step 2: Setting up RabbitMQ repository..."
curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | bash
check_status "RabbitMQ repository setup"

# STEP 3: Install RabbitMQ
print_message "Step 3: Installing RabbitMQ server..."
yum install rabbitmq-server -y
check_status "RabbitMQ installation"

# STEP 4: Enable and Start RabbitMQ
print_message "Step 4: Enabling RabbitMQ to start on boot..."
systemctl enable rabbitmq-server
check_status "RabbitMQ enable"

print_message "Step 5: Starting RabbitMQ service..."
systemctl start rabbitmq-server
check_status "RabbitMQ start"

# STEP 5: Create application user in RabbitMQ
print_message "Step 6: Creating RabbitMQ user 'roboshop'..."
rabbitmqctl add_user roboshop roboshop123
check_status "RabbitMQ user creation"

# STEP 6: Set permissions for the user
print_message "Step 7: Setting permissions for roboshop user..."
rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*"
check_status "RabbitMQ permissions"

# Verify RabbitMQ is running
if systemctl is-active --quiet rabbitmq-server; then
    print_message "✓ RabbitMQ is running successfully!"
else
    print_error "✗ RabbitMQ failed to start"
    exit 1
fi

echo ""
echo "=============================================="
print_message "RABBITMQ INSTALLATION COMPLETED SUCCESSFULLY!"
echo "=============================================="
print_message "RabbitMQ is listening on port: 5672"
print_message "RabbitMQ Username: roboshop"
print_message "RabbitMQ Password: roboshop123"
print_message "Next Step: Install Payment service"
echo ""
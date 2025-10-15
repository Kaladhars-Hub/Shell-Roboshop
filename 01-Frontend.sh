#!/bin/bash

# =============================================================================
# ROBOSHOP FRONTEND INSTALLATION SCRIPT
# =============================================================================
# This script installs and configures the Nginx web server for Roboshop
# Frontend serves the web interface to users
# =============================================================================

# Color codes for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if previous command was successful
check_status() {
    if [ $? -eq 0 ]; then
        print_message "$1 - SUCCESS"
    else
        print_error "$1 - FAILED"
        exit 1
    fi
}

# Check if running as root (needed for installation)
if [ $(id -u) -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

print_message "Starting Roboshop Frontend Installation..."
echo "=============================================="

# STEP 1: Install Nginx Web Server
print_message "Step 1: Installing Nginx web server..."
yum install nginx -y
check_status "Nginx installation"

# STEP 2: Enable and Start Nginx service
print_message "Step 2: Enabling Nginx to start on boot..."
systemctl enable nginx
check_status "Nginx enable"

print_message "Step 3: Starting Nginx service..."
systemctl start nginx
check_status "Nginx start"

# STEP 3: Remove default content
print_message "Step 4: Cleaning up default Nginx content..."
rm -rf /usr/share/nginx/html/*
check_status "Cleanup"

# STEP 4: Download Frontend application code
print_message "Step 5: Downloading Roboshop Frontend application..."
curl -o /tmp/frontend.zip https://roboshop-builds.s3.amazonaws.com/frontend.zip
check_status "Download frontend code"

# STEP 5: Extract the application code
print_message "Step 6: Extracting application files..."
cd /usr/share/nginx/html
unzip /tmp/frontend.zip
check_status "Extract frontend code"

# STEP 6: Configure Nginx reverse proxy
print_message "Step 7: Configuring Nginx reverse proxy..."
cat > /etc/nginx/default.d/roboshop.conf <<EOF
proxy_http_version 1.1;
location /images/ {
    expires 5s;
    root   /usr/share/nginx/html;
    try_files \$uri /images/placeholder.jpg;
}
location /api/catalogue/ { proxy_pass http://localhost:8080/; }
location /api/user/ { proxy_pass http://localhost:8080/; }
location /api/cart/ { proxy_pass http://localhost:8080/; }
location /api/shipping/ { proxy_pass http://localhost:8080/; }
location /api/payment/ { proxy_pass http://localhost:8080/; }

location /health {
    stub_status on;
    access_log off;
}
EOF
check_status "Nginx configuration"

# STEP 7: Restart Nginx to apply changes
print_message "Step 8: Restarting Nginx service..."
systemctl restart nginx
check_status "Nginx restart"

# Verify Nginx is running
if systemctl is-active --quiet nginx; then
    print_message "✓ Nginx is running successfully!"
else
    print_error "✗ Nginx failed to start"
    exit 1
fi

echo ""
echo "=============================================="
print_message "FRONTEND INSTALLATION COMPLETED SUCCESSFULLY!"
echo "=============================================="
print_message "Access your application at: http://$(hostname -I | awk '{print $1}')"
print_message "Next Step: Install MongoDB database"
echo ""
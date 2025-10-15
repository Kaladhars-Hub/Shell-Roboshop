#!/bin/bash

# Roboshop Frontend Installation Script
# This script installs and configures Nginx web server with Roboshop frontend application

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        print_info "$1 - SUCCESS"
    else
        print_error "$1 - FAILED"
        exit 1
    fi
}

# Main script starts here
print_info "Starting Roboshop Frontend Installation..."
echo "=============================================="

# Step 1: Install Nginx
print_info "Step 1: Installing Nginx web server..."
yum install nginx -y &>> /tmp/roboshop.log
check_status "Nginx installation"

# Step 2: Enable Nginx to start on boot
print_info "Step 2: Enabling Nginx to start on boot..."
systemctl enable nginx &>> /tmp/roboshop.log
check_status "Nginx enable"

# Step 3: Start Nginx service
print_info "Step 3: Starting Nginx service..."
systemctl start nginx &>> /tmp/roboshop.log
check_status "Nginx start"

# Step 4: Clean up default Nginx content
print_info "Step 4: Cleaning up default Nginx content..."
rm -rf /usr/share/nginx/html/* &>> /tmp/roboshop.log
check_status "Cleanup"

# Step 5: Download Roboshop Frontend application
print_info "Step 5: Downloading Roboshop Frontend application..."
curl -f -L -o /tmp/frontend.zip https://roboshop-builds.s3.amazonaws.com/frontend.zip &>> /tmp/roboshop.log
check_status "Download frontend code"

# Step 5.5: Verify the downloaded file is a valid ZIP
print_info "Step 5.5: Verifying downloaded file..."
if file /tmp/frontend.zip | grep -q "Zip archive"; then
    print_info "Valid ZIP file confirmed"
else
    print_error "Downloaded file is not a valid ZIP archive"
    print_warning "File type: $(file /tmp/frontend.zip)"
    exit 1
fi

# Step 6: Extract application files
print_info "Step 6: Extracting application files..."
cd /usr/share/nginx/html
unzip -o /tmp/frontend.zip &>> /tmp/roboshop.log
check_status "Extract frontend code"

# Step 7: Move files to proper location (if extracted in subdirectory)
print_info "Step 7: Organizing application files..."
if [ -d "frontend-main" ]; then
    mv frontend-main/* . &>> /tmp/roboshop.log
    rm -rf frontend-main &>> /tmp/roboshop.log
fi
check_status "File organization"

# Step 8: Clean up temporary files
print_info "Step 8: Cleaning up temporary files..."
rm -f /tmp/frontend.zip &>> /tmp/roboshop.log
check_status "Cleanup temporary files"

# Step 9: Restart Nginx to apply changes
print_info "Step 9: Restarting Nginx service..."
systemctl restart nginx &>> /tmp/roboshop.log
check_status "Nginx restart"

# Step 10: Verify Nginx is running
print_info "Step 10: Verifying Nginx status..."
systemctl is-active --quiet nginx
check_status "Nginx status verification"

# Final message
echo "=============================================="
print_info "Roboshop Frontend Installation - COMPLETED"
echo "=============================================="
print_info "You can access the application at: http://$(hostname -I | awk '{print $1}')"
print_info "Logs are available at: /tmp/roboshop.log"
echo ""
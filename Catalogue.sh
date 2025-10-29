#!/bin/bash

# =============================================
# ROBOSHOP - CATALOGUE COMPONENT SETUP SCRIPT
# =============================================
# This script installs and configures the Catalogue service
# Catalogue manages products in RoboShop application
# =============================================

# ====================
# SECTION 1: INITIAL SETUP
# ====================

# Shebang - tells system this is a Bash script
#!/bin/bash

# Set script to exit immediately if any command fails, use undefined variables, or any command in pipeline fails
set -euo pipefail

# Get current user ID to check if we're running as root
USERID=$(id -u)

# Color codes for pretty output
# \e[31m = Red, \e[32m = Green, \e[33m = Yellow, \e[0m = Reset color
R="\e[31m"  # Red for errors
G="\e[32m"  # Green for success
Y="\e[33m"  # Yellow for warnings/skipping
N="\e[0m"   # No color (reset)

# Logging setup
LOGS_FOLDER="/var/log/Shell-Roboshop"                    # Where to store log files
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)           # Get script name without extension
SCRIPT_DIR=$(pwd)                                       # Use $(pwd) to get current directory
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"                # Full path to log file

# MongoDB connection details (from our foundation script)
MONGODB_HOST="mongodb.awslearning.fun"                  # MongoDB server address

# ====================
# SECTION 2: FUNCTIONS
# ====================

# Function to create logs directory if it doesn't exist
setup_logging() {
    mkdir -p "$LOGS_FOLDER"                             # -p creates parent directories if needed
    echo "Script started at: $(date)" | tee -a "$LOG_FILE"  # tee shows output AND writes to log
}

# Function to check if running as root (required for installations)
check_root() {
    echo "Checking user privileges..." | tee -a "$LOG_FILE"
    # Root user has ID 0, if not root, show error and exit
    if [ "$USERID" -ne 0 ]; then
        echo -e "${R}ERROR:: Please run this script with root privilege (sudo)${N}" | tee -a "$LOG_FILE"
        exit 1  # Exit with error code 1
    fi
    echo -e "${G}SUCCESS:: Running with root privileges${N}" | tee -a "$LOG_FILE"
}

# Function to validate command execution
VALIDATE(){
    local exit_code=$1    # First argument: exit code of previous command ($?)
    local action_name=$2  # Second argument: description of what we tried to do
    
    # If exit code is NOT 0 (command failed)
    if [ "$exit_code" -ne 0 ]; then
        echo -e "$action_name ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
        exit 1  # Stop script immediately
    else
        echo -e "$action_name ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
    fi
}

# ====================
# SECTION 3: NODEJS SETUP
# ====================

setup_nodejs() {
    echo -e "\n${Y}=== SETTING UP NODEJS RUNTIME ===${N}" | tee -a "$LOG_FILE"
    
    # Disable existing NodeJS modules to avoid conflicts
    echo "Disabling existing NodeJS modules..." | tee -a "$LOG_FILE"
    dnf module disable nodejs -y &>>"$LOG_FILE"  # &>> redirects both stdout and stderr to log
    VALIDATE $? "Disable existing NodeJS modules"
    
    # Enable NodeJS 20 specifically (LTS version)
    echo "Enabling NodeJS 20..." | tee -a "$LOG_FILE"
    dnf module enable nodejs:20 -y &>>"$LOG_FILE"
    VALIDATE $? "Enable NodeJS 20 module"
    
    # Install NodeJS and npm
    echo "Installing NodeJS package..." | tee -a "$LOG_FILE"
    dnf install nodejs -y &>>"$LOG_FILE"
    VALIDATE $? "Install NodeJS"
    
    # Verify NodeJS installation
    echo "Verifying NodeJS installation..." | tee -a "$LOG_FILE"
    node --version &>>"$LOG_FILE"
    npm --version &>>"$LOG_FILE"
    echo -e "${G}NodeJS setup completed${N}" | tee -a "$LOG_FILE"
}

# ====================
# SECTION 4: APPLICATION USER & DIRECTORY
# ====================

setup_app_environment() {
    echo -e "\n${Y}=== SETTING UP APPLICATION ENVIRONMENT ===${N}" | tee -a "$LOG_FILE"
    
    # Create application directory
    # Idempotent check: only create if doesn't exist
    if [ ! -d /app ]; then
        echo "Creating application directory..." | tee -a "$LOG_FILE"
        mkdir -p /app &>>"$LOG_FILE"  # -p prevents errors if parent directories don't exist
        VALIDATE $? "Create /app directory"
    else
        echo -e "App directory already exists ... ${Y}SKIPPING${N}" | tee -a "$LOG_FILE"
    fi
    
    # Create dedicated user for catalogue service (security best practice)
    # Idempotent check: only create if user doesn't exist
    echo "Checking if roboshop user exists..." | tee -a "$LOG_FILE"
    id roboshop &>>"$LOG_FILE"  # Check if user exists (redirect output to log)
    if [ $? -ne 0 ]; then  # If previous command failed (user doesn't exist)
        echo "Creating roboshop system user..." | tee -a "$LOG_FILE"
        # --system: system user, --home: home directory, --shell: no login shell, --comment: description
        useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
        VALIDATE $? "Create roboshop system user"
    else
        echo -e "User roboshop already exists ... ${Y}SKIPPING${N}" | tee -a "$LOG_FILE"
    fi
}

# ====================
# SECTION 5: APPLICATION CODE DEPLOYMENT
# ====================

deploy_application() {
    echo -e "\n${Y}=== DEPLOYING CATALOGUE APPLICATION ===${N}" | tee -a "$LOG_FILE"
    
    # Download catalogue application code
    # Try S3 first, if fails try GitHub (fallback mechanism)
    echo "Downloading catalogue application..." | tee -a "$LOG_FILE"
    if ! curl -f -L -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue.zip &>>"$LOG_FILE"; then
        echo -e "${Y}S3 download failed, trying GitHub...${N}" | tee -a "$LOG_FILE"
        curl -f -L -o /tmp/catalogue.zip https://github.com/roboshop-devops-project/catalogue/archive/refs/heads/main.zip &>>"$LOG_FILE"
    fi
    VALIDATE $? "Download catalogue application"
    
    # Navigate to application directory
    echo "Changing to application directory..." | tee -a "$LOG_FILE"
    cd /app 
    VALIDATE $? "Change to /app directory"
    
    # Clean up any existing code (idempotent - ensures fresh deployment)
    echo "Cleaning up existing code..." | tee -a "$LOG_FILE"
    rm -rf /app/* &>>"$LOG_FILE"  # Remove everything in /app
    VALIDATE $? "Clean existing code"
    
    # Extract the downloaded zip file
    echo "Extracting application code..." | tee -a "$LOG_FILE"
    unzip -o /tmp/catalogue.zip &>>"$LOG_FILE"  # -o overwrites without prompting
    VALIDATE $? "Extract catalogue application"
    
    # If code was downloaded from GitHub, it creates a subdirectory
    # Move files from subdirectory to main app directory
    if [ -d /app/catalogue-main ]; then
        echo "Moving files from GitHub structure..." | tee -a "$LOG_FILE"
        mv /app/catalogue-main/* /app/ &>>"$LOG_FILE"    # Move all files
        rm -rf /app/catalogue-main &>>"$LOG_FILE"        # Remove empty directory
        VALIDATE $? "Reorganize application structure"
    fi
    
    # Install NodeJS dependencies
    echo "Installing NodeJS dependencies..." | tee -a "$LOG_FILE"
    npm install &>>"$LOG_FILE"  # Reads package.json and installs all dependencies
    VALIDATE $? "Install NodeJS dependencies"
}

# ====================
# SECTION 6: SERVICE CONFIGURATION
# ====================

configure_service() {
    echo -e "\n${Y}=== CONFIGURING SYSTEM SERVICE ===${N}" | tee -a "$LOG_FILE"
    
    # Create systemd service file
    # This tells systemd how to manage our catalogue application

    echo "Copying catalogue service file..." | tee -a "$LOG_FILE"
    cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service
    VALIDATE $? "Copy catalogue service file"
    
    # Set proper ownership of application directory
    echo "Setting application directory ownership..." | tee -a "$LOG_FILE"
    chown -R roboshop:roboshop /app &>>"$LOG_FILE"  # -R recursive, change owner:group
    VALIDATE $? "Set app directory ownership"
    
    # Reload systemd to recognize new service
    echo "Reloading systemd daemon..." | tee -a "$LOG_FILE"
    systemctl daemon-reload &>>"$LOG_FILE"
    VALIDATE $? "Reload systemd daemon"
    
    # Enable service to start automatically on boot
    echo "Enabling catalogue service..." | tee -a "$LOG_FILE"
    systemctl enable catalogue &>>"$LOG_FILE"
    VALIDATE $? "Enable catalogue service"
    
    # Start the service now
    echo "Starting catalogue service..." | tee -a "$LOG_FILE"
    systemctl start catalogue &>>"$LOG_FILE"
    VALIDATE $? "Start catalogue service"
}

# ====================
# SECTION 7: DATABASE SETUP
# ====================

setup_database() {
    echo -e "\n${Y}=== SETTING UP DATABASE CONNECTION ===${N}" | tee -a "$LOG_FILE"
    
    # Create MongoDB repository configuration

    echo "Copying MongoDB repository file..." | tee -a "$LOG_FILE"
    cp $SCRIPT_DIR/mongodb-org-7.0.repo /etc/yum.repos.d/mongodb-org-7.0.repo
    VALIDATE $? "Copy MongoDB repository file"
    
    # Install MongoDB client (mongosh) to interact with database
    echo "Installing MongoDB client..." | tee -a "$LOG_FILE"
    dnf clean all &>>"$LOG_FILE"  # Clean package cache
    
    # Try installing from repo, if fails try direct download
    if ! dnf install mongodb-mongosh-shared-openssl3 -y &>>"$LOG_FILE"; then
        echo "Trying alternative MongoDB client installation..." | tee -a "$LOG_FILE"
        dnf install -y https://downloads.mongodb.com/compass/mongodb-mongosh-2.3.2.x86_64.rpm &>>"$LOG_FILE"
    fi
    VALIDATE $? "Install MongoDB client"
    
    # Wait for MongoDB to be ready (important for automation)
    echo -e "${Y}Waiting for MongoDB to be ready...${N}" | tee -a "$LOG_FILE"
    for i in {1..30}; do  # Try 30 times with 2-second intervals
        if mongosh --host $MONGODB_HOST --eval "db.version()" &>>"$LOG_FILE"; then
            echo -e "${G}MongoDB is ready!${N}" | tee -a "$LOG_FILE"
            break
        fi
        echo -e "Attempt $i/30 - Waiting for MongoDB..." | tee -a "$LOG_FILE"
        sleep 2  # Wait 2 seconds before retry
    done
    
    # Load initial data into MongoDB (products, categories, etc.)
    echo "Loading initial data into MongoDB..." | tee -a "$LOG_FILE"
    mongosh --host $MONGODB_HOST </app/db/master-data.js &>>"$LOG_FILE"
    VALIDATE $? "Load catalogue initial data"
    
    # Restart service to ensure it picks up database connection
    echo "Restarting catalogue service..." | tee -a "$LOG_FILE"
    systemctl restart catalogue &>>"$LOG_FILE"
    VALIDATE $? "Restart catalogue service"
}

# ====================
# SECTION 8: VERIFICATION
# ====================

verify_installation() {
    echo -e "\n${Y}=== VERIFYING INSTALLATION ===${N}" | tee -a "$LOG_FILE"
    
    # Check if service is running
    if systemctl is-active --quiet catalogue; then
        echo -e "${G}✓ Catalogue service is RUNNING${N}" | tee -a "$LOG_FILE"
    else
        echo -e "${R}✗ Catalogue service is NOT running${N}" | tee -a "$LOG_FILE"
        exit 1
    fi
    
    # Check if service is enabled to start on boot
    if systemctl is-enabled --quiet catalogue; then
        echo -e "${G}✓ Catalogue service is ENABLED${N}" | tee -a "$LOG_FILE"
    else
        echo -e "${R}✗ Catalogue service is NOT enabled${N}" | tee -a "$LOG_FILE"
    fi
    
    # Check if application can respond (basic health check)
    echo "Performing basic health check..." | tee -a "$LOG_FILE"
    sleep 5  # Give service time to start completely
    
    if curl -f -s http://localhost:8080/health &>/dev/null; then
        echo -e "${G}✓ Catalogue application is RESPONDING${N}" | tee -a "$LOG_FILE"
    else
        echo -e "${Y}⚠ Catalogue application health check failed (may need more time)${N}" | tee -a "$LOG_FILE"
    fi
}

# ====================
# SECTION 9: MAIN EXECUTION
# ====================

main() {
    echo -e "\n${G}🚀 STARTING CATALOGUE COMPONENT SETUP${N}" | tee -a "$LOG_FILE"
    
    setup_logging
    check_root
    setup_nodejs
    setup_app_environment
    deploy_application
    configure_service
    setup_database
    verify_installation
    
    echo -e "\n${G}===============================================${N}" | tee -a "$LOG_FILE"
    echo -e "${G}✅ CATALOGUE INSTALLATION - COMPLETED SUCCESSFULLY${N}" | tee -a "$LOG_FILE"
    echo -e "${G}===============================================${N}" | tee -a "$LOG_FILE"
    echo -e "${Y}📝 Log file: $LOG_FILE${N}" | tee -a "$LOG_FILE"
    echo -e "${Y}🌐 Service should be available on port 8080${N}" | tee -a "$LOG_FILE"
    echo -e "${Y}📊 Database: MongoDB at $MONGODB_HOST${N}" | tee -a "$LOG_FILE"
    echo "Script completed at: $(date)" | tee -a "$LOG_FILE"
}

# ====================
# SECTION 10: SCRIPT START
# ====================

# Call the main function to start execution
main
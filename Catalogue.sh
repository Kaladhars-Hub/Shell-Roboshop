#!/bin/bash

# =============================================
# ROBOSHOP - CATALOGUE COMPONENT SETUP SCRIPT
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
R="\e[31m"  # Red for errors
G="\e[32m"  # Green for success
Y="\e[33m"  # Yellow for warnings/skipping
N="\e[0m"   # No color (reset)

# Logging setup
LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
SCRIPT_DIR=$(pwd)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

# MongoDB connection details
MONGODB_HOST="mongodb.awslearning.fun"

# ====================
# SECTION 2: INITIALIZATION
# ====================

# Create logs directory and file first
mkdir -p "$LOGS_FOLDER"
touch "$LOG_FILE"

# Write initial message
echo "Script started at: $(date)" | tee -a "$LOG_FILE"

if [ "$USERID" -ne 0 ]; then
    echo -e "${R}ERROR:: Please run this script with root privilege${N}" | tee -a "$LOG_FILE"
    exit 1
fi

# ====================
# SECTION 3: FUNCTIONS
# ====================

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

# ====================
# SECTION 4: NODEJS SETUP
# ====================

echo -e "\n${Y}=== SETTING UP NODEJS RUNTIME ===${N}" | tee -a "$LOG_FILE"

dnf module disable nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Disabling NodeJS"

dnf module enable nodejs:20 -y &>>"$LOG_FILE"
VALIDATE $? "Enabling NodeJS"

dnf install nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Installing NodeJS"

# ====================
# SECTION 5: APPLICATION USER & DIRECTORY
# ====================

echo -e "\n${Y}=== SETTING UP APPLICATION ENVIRONMENT ===${N}" | tee -a "$LOG_FILE"

# Create application directory
if [ ! -d /app ]; then
    mkdir -p /app &>>"$LOG_FILE"
    VALIDATE $? "Creating app directory"
else
    echo -e "App directory already exists ... ${Y}SKIPPING${N}" | tee -a "$LOG_FILE"
fi

# Create roboshop user
id roboshop &>>"$LOG_FILE"
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
    VALIDATE $? "Creating system user"
else
    echo -e "User already exists ... ${Y}SKIPPING${N}" | tee -a "$LOG_FILE"
fi

# ====================
# SECTION 6: APPLICATION CODE DEPLOYMENT
# ====================

echo -e "\n${Y}=== DEPLOYING CATALOGUE APPLICATION ===${N}" | tee -a "$LOG_FILE"

# Download catalogue application
if ! curl -f -L -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue.zip &>>"$LOG_FILE"; then
    echo -e "${Y}S3 download failed, trying GitHub...${N}" | tee -a "$LOG_FILE"
    curl -f -L -o /tmp/catalogue.zip https://github.com/roboshop-devops-project/catalogue/archive/refs/heads/main.zip &>>"$LOG_FILE"
fi
VALIDATE $? "Downloading catalogue application"

# Change to app directory
cd /app 
VALIDATE $? "Changing to app directory"

# Remove existing code
rm -rf /app/* &>>"$LOG_FILE"
VALIDATE $? "Removing existing code"

# Unzip catalogue
unzip -o /tmp/catalogue.zip &>>"$LOG_FILE"
VALIDATE $? "Unzip catalogue"

# Fix GitHub directory structure if needed
if [ -d /app/catalogue-main ]; then
    mv /app/catalogue-main/* /app/ &>>"$LOG_FILE"
    rm -rf /app/catalogue-main &>>"$LOG_FILE"
fi

# Install dependencies
npm install &>>"$LOG_FILE"
VALIDATE $? "Install dependencies"

# ====================
# SECTION 7: SERVICE CONFIGURATION
# ====================

echo -e "\n${Y}=== CONFIGURING SYSTEM SERVICE ===${N}" | tee -a "$LOG_FILE"

# Copy service file (make sure catalogue.service exists in same directory)
if [ -f "$SCRIPT_DIR/catalogue.service" ]; then
    cp "$SCRIPT_DIR/catalogue.service" /etc/systemd/system/catalogue.service
    VALIDATE $? "Copy catalogue service file"
else
    echo -e "${R}ERROR: catalogue.service file not found in $SCRIPT_DIR${N}" | tee -a "$LOG_FILE"
    exit 1
fi

# Set ownership
chown -R roboshop:roboshop /app &>>"$LOG_FILE"
VALIDATE $? "Set app directory ownership"

# Reload systemd
systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Daemon reload"

systemctl enable catalogue &>>"$LOG_FILE"
VALIDATE $? "Enable catalogue"

systemctl start catalogue &>>"$LOG_FILE"
VALIDATE $? "Start catalogue"

# ====================
# SECTION 8: COMPLETION
# ====================

echo -e "\n${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${G}✅ CATALOGUE INSTALLATION COMPLETED${N}" | tee -a "$LOG_FILE"
echo -e "${G}===============================================${N}" | tee -a "$LOG_FILE"
echo "Script completed at: $(date)" | tee -a "$LOG_FILE"
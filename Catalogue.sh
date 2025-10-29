#!/bin/bash

# =============================================
# ROBOSHOP - CATALOGUE COMPONENT SETUP SCRIPT
# =============================================

# ====================
# SECTION 1: CONFIGURATION
# ====================

# AMI Configuration
AMI_ID="ami-09c813fb71547fc4f"                    # Base AMI ID
MONGODB_HOST="mongodb.awslearning.fun"            # MongoDB host from Route53

# Script Configuration
USERID=$(id -u)
SCRIPT_DIR=$(pwd)

# Color codes
R="\e[31m"  # Red for errors
G="\e[32m"  # Green for success  
Y="\e[33m"  # Yellow for warnings
N="\e[0m"   # No color (reset)

# Logging setup
LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

# ====================
# SECTION 2: INITIALIZATION
# ====================

# Create logs directory and file
mkdir -p "$LOGS_FOLDER"
touch "$LOG_FILE"

# Write initial message
echo "===============================================" | tee -a "$LOG_FILE"
echo "Catalogue Setup Started at: $(date)" | tee -a "$LOG_FILE"
echo "AMI ID: $AMI_ID" | tee -a "$LOG_FILE"
echo "MongoDB Host: $MONGODB_HOST" | tee -a "$LOG_FILE"
echo "===============================================" | tee -a "$LOG_FILE"

# Root check
if [ "$USERID" -ne 0 ]; then
    echo -e "${R}ERROR: Run with root privilege${N}" | tee -a "$LOG_FILE"
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

echo -e "\n${Y}=== SETTING UP NODEJS ===${N}" | tee -a "$LOG_FILE"

dnf module disable nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Disable NodeJS"

dnf module enable nodejs:20 -y &>>"$LOG_FILE" 
VALIDATE $? "Enable NodeJS 20"

dnf install nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Install NodeJS"

# ====================
# SECTION 5: APPLICATION SETUP
# ====================

echo -e "\n${Y}=== SETTING UP APPLICATION ===${N}" | tee -a "$LOG_FILE"

# Create app directory
[ ! -d /app ] && mkdir -p /app &>>"$LOG_FILE"
VALIDATE $? "Create app directory"

# Create user
id roboshop &>/dev/null || useradd --system --home /app --shell /sbin/nologin roboshop &>>"$LOG_FILE"
VALIDATE $? "Create roboshop user"

# Download and deploy app
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Download application"

cd /app && unzip -o /tmp/catalogue.zip &>>"$LOG_FILE"
VALIDATE $? "Extract application"

npm install &>>"$LOG_FILE"
VALIDATE $? "Install dependencies"

# ====================
# SECTION 6: SERVICE SETUP (USING COPY)
# ====================

echo -e "\n${Y}=== CONFIGURING SERVICE ===${N}" | tee -a "$LOG_FILE"

# Copy service file - PROFESSIONAL APPROACH
cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? "Copy service file"

chown -R roboshop:roboshop /app &>>"$LOG_FILE"
VALIDATE $? "Set ownership"

systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Reload systemd"

systemctl enable catalogue &>>"$LOG_FILE"
VALIDATE $? "Enable service"

systemctl start catalogue &>>"$LOG_FILE"  
VALIDATE $? "Start service"

# ====================
# SECTION 7: DATABASE SETUP (USING COPY)
# ====================

echo -e "\n${Y}=== SETTING UP DATABASE ===${N}" | tee -a "$LOG_FILE"

# Copy MongoDB repo - PROFESSIONAL APPROACH
cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "Copy MongoDB repo"

dnf install mongodb-mongosh -y &>>"$LOG_FILE"
VALIDATE $? "Install MongoDB client"

mongosh --host $MONGODB_HOST </app/db/master-data.js &>>"$LOG_FILE"
VALIDATE $? "Load database data"

# ====================
# SECTION 8: COMPLETION
# ====================

echo -e "\n${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${G}✅ CATALOGUE INSTALLATION COMPLETED${N}" | tee -a "$LOG_FILE"
echo -e "${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${Y}AMI: $AMI_ID${N}" | tee -a "$LOG_FILE"
echo -e "${Y}MongoDB: $MONGODB_HOST${N}" | tee -a "$LOG_FILE"
echo "Completed at: $(date)" | tee -a "$LOG_FILE"
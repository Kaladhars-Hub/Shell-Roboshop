#!/bin/bash

# =============================================================================
# ROBOSHOP CATALOGUE SERVICE INSTALLATION SCRIPT
# =============================================================================
# This script installs and configures the Catalogue microservice
# Catalogue manages product listings in RoboShop application
# =============================================================================

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGODB_HOST=mongodb.awslearning.fun
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
START_TIME=$(date +%s)

mkdir -p "$LOGS_FOLDER"
echo "Script started at: $(date)" | tee -a "$LOG_FILE"

if [ "$USERID" -ne 0 ]; then
    echo -e "${R}ERROR:: Please run this script with root privilege${N}" | tee -a "$LOG_FILE"
    exit 1
fi

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

# Disable existing NodeJS modules
dnf module disable nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Disable existing NodeJS modules"

# Enable NodeJS 20
dnf module enable nodejs:20 -y &>>"$LOG_FILE"
VALIDATE $? "Enable NodeJS 20"

# Install NodeJS
dnf install nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Install NodeJS"

# Create roboshop user if doesn't exist
id roboshop &>>"$LOG_FILE"
if [ $? -ne 0 ]; then
    useradd roboshop &>>"$LOG_FILE"
    VALIDATE $? "Create roboshop user"
else
    echo -e "roboshop user already exists ... ${Y}SKIPPING${N}" | tee -a "$LOG_FILE"
fi

# Create app directory
mkdir -p /app &>>"$LOG_FILE"
VALIDATE $? "Create /app directory"

# Download catalogue application
curl -L -o /tmp/catalogue.zip https://roboshop-builds.s3.amazonaws.com/catalogue.zip &>>"$LOG_FILE"
VALIDATE $? "Download catalogue application"

# Extract application
cd /app
rm -rf /app/* &>>"$LOG_FILE"
unzip -o /tmp/catalogue.zip &>>"$LOG_FILE"
VALIDATE $? "Extract catalogue application"

# Install npm dependencies
npm install &>>"$LOG_FILE"
VALIDATE $? "Install npm dependencies"

# Copy catalogue service file
cp "$SCRIPT_DIR/catalogue.service" /etc/systemd/system/catalogue.service &>>"$LOG_FILE"
VALIDATE $? "Copy catalogue service file"

# Set ownership
chown -R roboshop:roboshop /app &>>"$LOG_FILE"
VALIDATE $? "Set app directory ownership"

# Reload systemd
systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Reload systemd daemon"

# Enable catalogue service
systemctl enable catalogue &>>"$LOG_FILE"
VALIDATE $? "Enable catalogue service"

# Start catalogue service
systemctl start catalogue &>>"$LOG_FILE"
VALIDATE $? "Start catalogue service"

# Copy MongoDB repo file
cp "$SCRIPT_DIR/mongo.repo" /etc/yum.repos.d/mongo.repo &>>"$LOG_FILE"
VALIDATE $? "Copy MongoDB repository file"

# Install MongoDB client
dnf install mongodb-mongosh -y &>>"$LOG_FILE"
VALIDATE $? "Install MongoDB client"

# Load data 
mongosh --host mongodb.awslearning.fun < /app/schema/catalogue.js
VALIDATE $? "Load catalogue data"

# Restart catalogue service
systemctl restart catalogue &>>"$LOG_FILE"
VALIDATE $? "Restart catalogue service"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME ))
echo -e "Script executed in: $Y $TOTAL_TIME Seconds $N" | tee -a "$LOG_FILE"
#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
SCRIPT_DIR=$PWD
MONGODB_HOST=mongodb.awslearning.fun
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

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

# Disable and enable NodeJS module
dnf module disable nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Disabling NodeJS"

dnf module enable nodejs:20 -y &>>"$LOG_FILE"
VALIDATE $? "Enabling NodeJS"

dnf install nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Installing NodeJS"

# Check if roboshop user exists, if not create it
id roboshop &>>"$LOG_FILE"
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
    VALIDATE $? "Creating system user"
else
    echo -e "User already exists ... ${Y}SKIPPING${N}" | tee -a "$LOG_FILE"
fi

# Create /app directory first (before creating user)
    mkdir -p /app &>>"$LOG_FILE"
    VALIDATE $? "Creating app directory"

# Download catalogue application
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Downloading catalogue application"

# Change to app directory
cd /app 
VALIDATE $? "Changing to app directory"

# Remove existing code
rm -rf /app/* &>>"$LOG_FILE"
VALIDATE $? "Removing existing code"

# Unzip catalogue
unzip /tmp/catalogue.zip &>>"$LOG_FILE"
VALIDATE $? "Unzip catalogue"

# Install dependencies
npm install &>>"$LOG_FILE"
VALIDATE $? "Install dependencies"

# Copy systemd service file
cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service &>>"$LOG_FILE"
VALIDATE $? "Copy systemctl service"

# Reload daemon and enable service
systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Daemon reload"

systemctl enable catalogue &>>"$LOG_FILE"
VALIDATE $? "Enable catalogue"

systemctl start catalogue &>>"$LOG_FILE"
VALIDATE $? "Start catalogue"

# Copy mongo repo
cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo &>>"$LOG_FILE"
VALIDATE $? "Copy mongo repo"

# Install mongodb client
dnf install mongodb-mongosh -y &>>"$LOG_FILE"
VALIDATE $? "Install mongodb client"

# Load catalogue products into MongoDB
mongosh --host $MONGODB_HOST </app/db/master-data.js &>>"$LOG_FILE"
VALIDATE $? "Load catalogue products"

# Restart catalogue service
systemctl restart catalogue &>>"$LOG_FILE"
VALIDATE $? "Restarted catalogue"

echo "Script completed at: $(date)" | tee -a "$LOG_FILE"

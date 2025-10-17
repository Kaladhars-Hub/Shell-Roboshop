#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
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

# Create /app directory first
if [ ! -d /app ]; then
    mkdir -p /app &>>"$LOG_FILE"
    VALIDATE $? "Creating app directory"
else
    echo -e "App directory already exists ... ${Y}SKIPPING${N}" | tee -a "$LOG_FILE"
fi

# Check if roboshop user exists, if not create it
id roboshop &>>"$LOG_FILE"
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
    VALIDATE $? "Creating system user"
else
    echo -e "User already exists ... ${Y}SKIPPING${N}" | tee -a "$LOG_FILE"
fi

# Download catalogue application (try GitHub if S3 fails)
if ! curl -f -L -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>"$LOG_FILE"; then
    echo -e "S3 download failed, trying GitHub..." | tee -a "$LOG_FILE"
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

# Install dependencies
npm install &>>"$LOG_FILE"
VALIDATE $? "Install dependencies"

# Create systemd service file
cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? "Copy systemctl service"

# Set proper ownership for /app
chown -R roboshop:roboshop /app &>>"$LOG_FILE"
VALIDATE $? "Set app directory ownership"

# Reload daemon and enable service 
systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Daemon reload"

systemctl enable catalogue &>>"$LOG_FILE"
VALIDATE $? "Enable catalogue"

systemctl start catalogue &>>"$LOG_FILE"
VALIDATE $? "Start catalogue"

# Create MongoDB repository
cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongodb-org-7.0.repo <<EOF
VALIDATE $? "Copy mongo repository"

# Install mongodb client
dnf instal mongodb-mongosh -y &>>$LOG_FILE
VALIDATE $? "Install mongodb client"

# Wait for MongoDB to be ready
echo -e "Waiting for MongoDB to be ready..." | tee -a "$LOG_FILE"
for i in {1..30}; do
    if mongosh --host $MONGODB_HOST --eval "db.version()" &>>"$LOG_FILE"; then
        echo -e "MongoDB is ready!" | tee -a "$LOG_FILE"
        break
    fi
    echo -e "Attempt $i/30 - Waiting for MongoDB..." | tee -a "$LOG_FILE"
    sleep 2
done

# Load catalogue products into MongoDB
mongosh --host $MONGODB_HOST </app/db/master-data.js &>>"$LOG_FILE"
VALIDATE $? "Load catalogue products"

# Restart catalogue service to apply changes
systemctl restart catalogue &>>"$LOG_FILE"
VALIDATE $? "Restarted catalogue"

echo "=============================================="
echo -e "${G}Catalogue Installation - COMPLETED${N}" | tee -a "$LOG_FILE"
echo "=============================================="
echo "Script completed at: $(date)" | tee -a "$LOG_FILE"


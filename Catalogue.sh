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

# Create /app directory first (before creating user)
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

# Download catalogue application
curl -L -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>"$LOG_FILE"
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

# Fix: Find the actual application directory
# If unzip created a subdirectory, navigate into it
if [ -d /app/catalogue ]; then
    cd /app/catalogue
    # Copy all contents to /app root
    cp -r . /app/
    cd /app
fi

VALIDATE $? "Changing to app directory"

# Install dependencies
npm install &>>"$LOG_FILE"
VALIDATE $? "Install dependencies"

# Fix: Create the systemd service file manually since it might not exist
cat > /etc/systemd/system/catalogue.service <<EOF
[Unit]
Description = Catalogue Service
[Service]
User=roboshop
Environment=MONGO=true
Environment=MONGO_URL="mongodb://${MONGODB_HOST}:27017/catalogue"
ExecStart=/bin/node /app/server.js
SyslogIdentifier=catalogue

[Install]
WantedBy=multi-user.target
EOF

VALIDATE $? "Create systemd service file"

# Fix: Change ownership of /app to roboshop user
chown -R roboshop:roboshop /app &>>"$LOG_FILE"
VALIDATE $? "Change app ownership"

# Reload daemon and enable service
systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Daemon reload"

systemctl enable catalogue &>>"$LOG_FILE"
VALIDATE $? "Enable catalogue"

systemctl start catalogue &>>"$LOG_FILE"
VALIDATE $? "Start catalogue"

# Fix: Check if mongo.repo exists in /app before copying
if [ -f /app/mongo.repo ]; then
    cp /app/mongo.repo /etc/yum.repos.d/mongo.repo &>>"$LOG_FILE"
    VALIDATE $? "Copy mongo repo"
else
    # Create mongo.repo if it doesn't exist
    cat > /etc/yum.repos.d/mongo.repo <<EOF
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF
    VALIDATE $? "Create mongo repo"
fi

# Install mongodb client
if dnf install mongodb-mongosh-shared-openssl3 -y &>>"$LOG_FILE"; then
    echo -e "Install mongodb client ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
elif dnf install mongodb-org-mongosh -y &>>"$LOG_FILE"; then
    echo -e "Install mongodb client ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
elif dnf install -y https://downloads.mongodb.com/compass/mongodb-mongosh-2.3.2.x86_64.rpm &>>"$LOG_FILE"; then
    echo -e "Install mongodb client ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
else
    echo -e "Install mongodb client ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
    exit 1
fi

# Fix: Check if master-data.js exists before loading
if [ -f /app/db/master-data.js ]; then
    mongosh --host $MONGODB_HOST </app/db/master-data.js &>>"$LOG_FILE"
    VALIDATE $? "Load catalogue products"
else
    echo -e "Master data file not found ... ${Y}SKIPPING${N}" | tee -a "$LOG_FILE"
fi

# Restart catalogue service
systemctl restart catalogue &>>"$LOG_FILE"
VALIDATE $? "Restarted catalogue"

# Fix: Check service status
echo -e "\nService Status:" | tee -a "$LOG_FILE"
systemctl status catalogue --no-pager -l | tee -a "$LOG_FILE"

echo "Script completed at: $(date)" | tee -a "$LOG_FILE"


#!/bin/bash

# =============================================
# ROBOSHOP - CATALOGUE COMPONENT SETUP SCRIPT
# =============================================

# ====================
# SECTION 1: CONFIGURATION
# ====================

MONGODB_HOST="mongodb.awslearning.fun"            # MongoDB host from Route53
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

rm -rf /app &>/dev/null
mkdir -p /app &>>"$LOG_FILE"
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
# SECTION 6: DATABASE SETUP (FIXED)
# ====================

echo -e "\n${Y}=== SETTING UP DATABASE ===${N}" | tee -a "$LOG_FILE"

# 1. Copy MongoDB repo FIRST
cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "Copy MongoDB repo"

# 2. Install MongoDB SERVER (not just client)
dnf install mongodb-org -y &>>"$LOG_FILE"
VALIDATE $? "Install MongoDB server"

# 3. Start and enable MongoDB service
systemctl enable mongod &>>"$LOG_FILE"
VALIDATE $? "Enable MongoDB service"

systemctl start mongod &>>"$LOG_FILE"
VALIDATE $? "Start MongoDB service"

# 4. Install MongoDB client
dnf install mongodb-mongosh -y &>>"$LOG_FILE"
VALIDATE $? "Install MongoDB client"

# 5. Wait for MongoDB to be ready
echo "Waiting for MongoDB to start..." | tee -a "$LOG_FILE"
sleep 10

# 6. Test MongoDB connection
echo "Testing MongoDB connection..." | tee -a "$LOG_FILE"
if mongosh --host $MONGODB_HOST --eval "db.adminCommand('ping')" &>>"$LOG_FILE"; then
    echo -e "${G}MongoDB connection successful${N}" | tee -a "$LOG_FILE"
else
    echo -e "${Y}Remote MongoDB connection failed, trying localhost...${N}" | tee -a "$LOG_FILE"
    MONGODB_HOST="localhost"
    mongosh --host $MONGODB_HOST --eval "db.adminCommand('ping')" &>>"$LOG_FILE"
    VALIDATE $? "Test local MongoDB connection"
fi

# 7. Load database data (only if file exists)
if [ -f /app/schema/catalogue.js ]; then
    echo "Loading catalogue schema..." | tee -a "$LOG_FILE"
    mongosh --host $MONGODB_HOST </app/schema/catalogue.js &>>"$LOG_FILE"
    VALIDATE $? "Load catalogue schema"
elif [ -f /app/db/master-data.js ]; then
    echo "Loading master data..." | tee -a "$LOG_FILE"
    mongosh --host $MONGODB_HOST </app/db/master-data.js &>>"$LOG_FILE"
    VALIDATE $? "Load master data"
else
    echo -e "${Y}No database script found, skipping data load${N}" | tee -a "$LOG_FILE"
fi

# ====================
# SECTION 7: SERVICE SETUP (MOVED AFTER DATABASE)
# ====================

echo -e "\n${Y}=== CONFIGURING SERVICE ===${N}" | tee -a "$LOG_FILE"

# Copy service file
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
# SECTION 8: COMPLETION
# ====================

echo -e "\n${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${G}✅ CATALOGUE INSTALLATION COMPLETED${N}" | tee -a "$LOG_FILE"
echo -e "${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${Y}AMI: $AMI_ID${N}" | tee -a "$LOG_FILE"
echo -e "${Y}MongoDB: $MONGODB_HOST${N}" | tee -a "$LOG_FILE"
echo -e "${Y}Service Status: $SERVICE_STATUS${N}" | tee -a "$LOG_FILE"
echo "Completed at: $(date)" | tee -a "$LOG_FILE"
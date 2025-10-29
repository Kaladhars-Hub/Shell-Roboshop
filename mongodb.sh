#!/bin/bash

# =============================================
# MONGODB SETUP SCRIPT
# =============================================

# Configuration
USERID=$(id -u)
R="\e[31m"; G="\e[32m"; Y="\e[33m"; N="\e[0m"
LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
SCRIPT_DIR=$(pwd)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

# Initialize
mkdir -p "$LOGS_FOLDER"
touch "$LOG_FILE"
echo "MongoDB setup started at: $(date)" | tee -a "$LOG_FILE"

if [ "$USERID" -ne 0 ]; then
    echo -e "${R}ERROR: Run with sudo${N}" | tee -a "$LOG_FILE"
    exit 1
fi

VALIDATE(){
    if [ "$1" -ne 0 ]; then
        echo -e "$2 ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "$2 ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
    fi
}

echo -e "\n${Y}=== SETTING UP MONGODB SERVER ===${N}" | tee -a "$LOG_FILE"

# ✅ PROFESSIONAL: Copy MongoDB repository file
echo "Copying MongoDB repository configuration..." | tee -a "$LOG_FILE"
cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "Copy MongoDB repo"

# Install MongoDB server
echo "Installing MongoDB server..." | tee -a "$LOG_FILE"
dnf install mongodb-org -y &>>"$LOG_FILE"
VALIDATE $? "Install MongoDB server"

# Configure MongoDB network
echo "Configuring MongoDB network settings..." | tee -a "$LOG_FILE"
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
VALIDATE $? "Configure MongoDB network"

# Start and enable MongoDB
echo "Starting MongoDB service..." | tee -a "$LOG_FILE"
systemctl enable mongod &>>"$LOG_FILE"
systemctl start mongod &>>"$LOG_FILE"
VALIDATE $? "Start MongoDB service"

# Restart with new configuration
systemctl restart mongod &>>"$LOG_FILE"
VALIDATE $? "Restart MongoDB"

# Verify installation
echo "Verifying MongoDB installation..." | tee -a "$LOG_FILE"
sleep 5
if systemctl is-active --quiet mongod; then
    echo -e "MongoDB status ... ${G}RUNNING${N}" | tee -a "$LOG_FILE"
    
    # Test MongoDB connection
    if mongosh --eval "db.version()" &>>"$LOG_FILE"; then
        echo -e "MongoDB connection ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
    else
        echo -e "MongoDB connection ... ${Y}WARNING${N}" | tee -a "$LOG_FILE"
    fi
else
    echo -e "MongoDB status ... ${R}NOT RUNNING${N}" | tee -a "$LOG_FILE"
    exit 1
fi

echo -e "\n${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${G}✅ MONGODB SERVER INSTALLATION COMPLETED${N}" | tee -a "$LOG_FILE"
echo -e "${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${Y}📊 MongoDB running on: 0.0.0.0:27017${N}" | tee -a "$LOG_FILE"
echo -e "${Y}🌐 Accessible from all network interfaces${N}" | tee -a "$LOG_FILE"
echo "Completed at: $(date)" | tee -a "$LOG_FILE"
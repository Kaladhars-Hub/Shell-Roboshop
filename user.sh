#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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

dnf module disable nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Disable NodeJS"

dnf module enable nodejs:20 -y &>>"$LOG_FILE" 
VALIDATE $? "Enable NodeJS 20"

dnf install nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Install NodeJS"

# ====================
# APPLICATION SETUP
# ====================

echo -e "\n${Y}=== SETTING UP APPLICATION ===${N}" | tee -a "$LOG_FILE"

rm -rf /app &>/dev/null
mkdir -p /app &>>"$LOG_FILE"
VALIDATE $? "Create app directory"

# Create user
id roboshop &>/dev/null || useradd --system --home /app --shell /sbin/nologin roboshop &>>"$LOG_FILE"
VALIDATE $? "Create roboshop user"

# Download and deploy app
curl -L -o /tmp/user.zip https://roboshop-artifacts.s3.amazonaws.com/user-v3.zip &>>"$LOG_FILE"  # ✅ FIXED: Added &>>"$LOG_FILE" and line break
VALIDATE $? "Download application"

cd /app && unzip -o /tmp/user.zip &>>"$LOG_FILE"
VALIDATE $? "Extract application"

npm install &>>"$LOG_FILE"
VALIDATE $? "Install dependencies"

# ====================
# SERVICE SETUP (USING COPY)
# ====================

echo -e "\n${Y}=== CONFIGURING SERVICE ===${N}" | tee -a "$LOG_FILE"

# Copy service file - PROFESSIONAL APPROACH
cp $SCRIPT_DIR/user.service /etc/systemd/system/user.service
VALIDATE $? "Copy service file"

chown -R roboshop:roboshop /app &>>"$LOG_FILE"
VALIDATE $? "Set ownership"

systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Reload systemd"

systemctl enable user &>>"$LOG_FILE"
VALIDATE $? "Enabling service"

systemctl start user &>>"$LOG_FILE"  
VALIDATE $? "Start service"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME))
echo -e "Script executed in: $Y $TOTAL_TIME Seconds $N"
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

dnf module disable nginx -y &>>"$LOG_FILE"
VALIDATE $? "Disable nginx"

dnf module enable nginx:1.24 -y &>>"$LOG_FILE"
VALIDATE $? "Enable nginx"

dnf install nginx -y &>>"$LOG_FILE"
VALIDATE $? "Install nginx"

# Start and enable Nginx services
echo "Starting nginx service..." | tee -a "$LOG_FILE"
systemctl enable nginx &>>"$LOG_FILE"
systemctl start nginx &>>"$LOG_FILE"
VALIDATE $? "Start nginx service"

# ====================
# APPLICATION SETUP
# ====================

echo -e "\n${Y}=== SETTING UP APPLICATION ===${N}" | tee -a "$LOG_FILE"

rm -rf /app &>/dev/null

# Download and deploy app
curl -L -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip
VALIDATE $? "Download application"

cd /app && unzip -o /tmp/frontend.zip &>>"$LOG_FILE"
VALIDATE $? "Extract application"

# ====================
# SERVICE SETUP (USING COPY)
# ====================

echo -e "\n${Y}=== CONFIGURING SERVICE ===${N}" | tee -a "$LOG_FILE"

# Copy service file - PROFESSIONAL APPROACH
cp $SCRIPT_DIR/nginx.conf /etc/systemd/system/nginx.conf
VALIDATE $? "Copy service file"

chown -R roboshop:roboshop /app &>>"$LOG_FILE"
VALIDATE $? "Set ownership"

systemctl restart nginx &>>"$LOG_FILE"
VALIDATE $? "Restart nginx service"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo -e "Script executed in: ${Y}${TOTAL_TIME} Seconds${N}" | tee -a "$LOG_FILE"
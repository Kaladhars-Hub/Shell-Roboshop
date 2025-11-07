#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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

# ====================
# NGINX INSTALLATION
# ====================

echo -e "\n${Y}=== INSTALLING NGINX ===${N}" | tee -a "$LOG_FILE"

dnf module disable nginx -y &>>"$LOG_FILE"
VALIDATE $? "Disable nginx"

dnf module enable nginx:1.24 -y &>>"$LOG_FILE"
VALIDATE $? "Enable nginx 1.24"

dnf install nginx -y &>>"$LOG_FILE"
VALIDATE $? "Install nginx"

# Enable Nginx service (but don't start it yet)
echo -e "\n${Y}=== ENABLING NGINX SERVICE ===${N}" | tee -a "$LOG_FILE"
systemctl enable nginx &>>"$LOG_FILE"
VALIDATE $? "Enable nginx service"

# ====================
# FRONTEND APPLICATION SETUP
# ====================

echo -e "\n${Y}=== SETTING UP FRONTEND APPLICATION ===${N}" | tee -a "$LOG_FILE"

# Remove default content
rm -rf /usr/share/nginx/html/* &>>"$LOG_FILE"
VALIDATE $? "Remove default nginx content"

# Download frontend content
curl -L -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Download frontend application"

# Extract frontend content
cd /usr/share/nginx/html &>>"$LOG_FILE"
unzip -o /tmp/frontend.zip &>>"$LOG_FILE"
VALIDATE $? "Extract frontend application"

# ====================
# NGINX CONFIGURATION
# ====================

echo -e "\n${Y}=== CONFIGURING NGINX REVERSE PROXY ===${N}" | tee -a "$LOG_FILE"

# Copy nginx.conf file - PROFESSIONAL APPROACH
cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf &>>"$LOG_FILE"
VALIDATE $? "Copy nginx configuration"

# Set proper ownership for nginx content
chown -R nginx:nginx /usr/share/nginx/html &>>"$LOG_FILE"
VALIDATE $? "Set nginx ownership"

# Restart Nginx to apply changes
systemctl restart nginx &>>"$LOG_FILE"
VALIDATE $? "Restart nginx service"

END_TIME=$(date +s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo -e "Script executed in: ${Y}${TOTAL_TIME} Seconds${N}" | tee -a "$LOG_FILE"
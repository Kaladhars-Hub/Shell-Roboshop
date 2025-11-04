#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
SCRIPT_DIR=$(pwd)  # ✅ ADDED: Missing SCRIPT_DIR
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

dnf install golang -y &>>"$LOG_FILE"
VALIDATE $? "Installing golang"

# Create user
id roboshop &>/dev/null || useradd --system --home /app --shell /sbin/nologin roboshop &>>"$LOG_FILE"
VALIDATE $? "Create roboshop user"

mkdir -p /app &>>"$LOG_FILE"
VALIDATE $? "Create app directory"

curl -L -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch.zip &>>"$LOG_FILE"
VALIDATE $? "Download application"

cd /app && unzip -o /tmp/dispatch.zip &>>"$LOG_FILE"
VALIDATE $? "Extract application"

cd /app
[ -f "go.mod" ] || go mod init dispatch &>>"$LOG_FILE"
VALIDATE $? "Initialize Go module"

go get &>>"$LOG_FILE"
VALIDATE $? "Download Go dependencies"

go build &>>"$LOG_FILE"
VALIDATE $? "Build Go application"

# ✅ ADDED: Check if service file exists before copying
if [ -f "$SCRIPT_DIR/dispatch.service" ]; then
    cp "$SCRIPT_DIR/dispatch.service" /etc/systemd/system/dispatch.service
    VALIDATE $? "Copy service file"
else
    echo -e "${R}ERROR: dispatch.service file not found${N}" | tee -a "$LOG_FILE"
    exit 1
fi

chown -R roboshop:roboshop /app &>>"$LOG_FILE"
VALIDATE $? "Set ownership"

systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Reload systemd"

systemctl enable dispatch &>>"$LOG_FILE"
VALIDATE $? "Enable dispatch"

systemctl start dispatch &>>"$LOG_FILE"
VALIDATE $? "Start dispatch"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo -e "Script executed in: ${Y}${TOTAL_TIME} Seconds${N}" | tee -a "$LOG_FILE"
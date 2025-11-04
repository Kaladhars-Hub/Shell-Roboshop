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

dnf install maven -y &>>"$LOG_FILE"
VALIDATE $? "Installing Maven"

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

# SERVICE SETUP SECTION
echo -e "\n${Y}=== CONFIGURING SERVICE ===${N}" | tee -a "$LOG_FILE"

cp $SCRIPT_DIR/dispatch.service /etc/systemd/system/dispatch.service &>>"$LOG_FILE"
VALIDATE $? "Copy service file"

chown -R roboshop:roboshop /app &>>"$LOG_FILE"
VALIDATE $? "Set ownership"

systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Reload systemd"

systemctl enable shipping &>>"$LOG_FILE"
VALIDATE $? "Enable service"

systemctl start shipping &>>"$LOG_FILE"
VALIDATE $? "Start service"

# ====================
# DATABASE SETUP
# ====================

echo -e "\n${Y}=== SETTING UP DATABASE ===${N}" | tee -a "$LOG_FILE"

dnf install mysql -y &>>"$LOG_FILE"
VALIDATE $? "Install MySQL client"

mysql -h mysql.awslearning.fun -uroot -pRoboShop@1 < /app/db/schema.sql &>>"$LOG_FILE"
VALIDATE $? "Load database schema"

mysql -h mysql.awslearning.fun -uroot -pRoboShop@1 < /app/db/app-user.sql &>>"$LOG_FILE"
VALIDATE $? "Create application user"

mysql -h mysql.awslearning.fun -uroot -pRoboShop@1 < /app/db/master-data.sql &>>"$LOG_FILE"
VALIDATE $? "Load master data"

systemctl restart shipping &>>"$LOG_FILE"
VALIDATE $? "Restart shipping service"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo -e "Script executed in: ${Y}${TOTAL_TIME} Seconds${N}" | tee -a "$LOG_FILE"
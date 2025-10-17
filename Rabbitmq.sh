#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
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

cp $SCRIPT_DIR/rabbitmq.repo /etc/yum.repos.d/rabbitmq.repo
VALIDATE $? "Adding RabbitMQ repo"
dnf install rabbitmq-server -y
VALIDATE $? "Installing RabbitMQ Server"
systemctl enable rabbitmq-server
VALIDATE $? "Enabling RabbitMQ Server"
systemctl start rabbitmq-server
VALIDATE $? "Starting RabbitMQ Server"
rabbitmqctl add_user roboshop roboshop123
rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*"
VALIDATE $? "Setting up permissions"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME))
echo -e "Script executed in: $Y $TOTAL_TIME Seconds $N"
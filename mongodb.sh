#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

mkdir -p "$LOGS_FOLDER"
echo "Script started at: $(date)" | tee -a "$LOG_FILE"

if [ "$USERID" -ne 0 ]; then
    echo -e "${R}ERROR:: Please run this script with root privilege${N}" | tee -a "$LOG_FILE"
    exit 1
fi

VALIDATE(){
    local exit_code=$1
    local package_name=$2
    
    if [ "$exit_code" -ne 0 ]; then
        echo -e "Installing $package_name ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "Installing $package_name ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
    fi
}

# Check if mongo.repo exists before copying
if [ ! -f "mongo.repo" ]; then
    echo -e "${R}ERROR:: mongo.repo file not found in current directory${N}" | tee -a "$LOG_FILE"
    exit 1
fi

cp mongo.repo /etc/yum.repos.d/mongo.repo &>>"$LOG_FILE"
VALIDATE $? "Adding Mongo repo"

dnf install mongodb-org -y &>>"$LOG_FILE"
VALIDATE $? "Installing MongoDB"

systemctl enable mongod &>>"$LOG_FILE"
VALIDATE $? "Enable MongoDB"

systemctl start mongod &>>"$LOG_FILE"
VALIDATE $? "Start MongoDB"

echo "Script completed at: $(date)" | tee -a "$LOG_FILE"


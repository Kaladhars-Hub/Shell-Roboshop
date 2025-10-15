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

dnf module disable nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Disabling NodeJS"
dnf module enable nodejs:20 -y &>>"$LOG_FILE"
VALIDATE $? "Enabling NodeJS"
dnf install nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Installing NodeJS"

id roboshop &>>"$LOG_FILE"
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
    VALIDATE $? "Creating system user"
else
    echo -e "user already exist ... $Y SKIPPING $N"
fi     

mkdir /app
VALIDATE $? "Creating app directory"

curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip 
VALIDATE $? "Downloading catalogue application"

cd /app 
VALIDATE $? "Changig to app directory"

rm -rf /app/*
VALIDATE $ "Removing existing code"

unzip /tmp/catalogue.zip &>>"$LOG_FILE"
VALIDATE $? "Unzip catalogue"

cd /app 
VALIDATE $? "Changig to app directory"

npm install &>>"$LOG_FILE"
VALIDATE $? "Install dependencies"

cp catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? "Copy systemctl service"

systemctl daemon-reload
systemctl enable catalogue &>>"$LOG_FILE"
VALIDATE $? "Enable catalogue"

cp mongo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "Copy mongo repo"
dnf install mongodb-mongosh -y &>>"$LOG_FILE"
VALIDATE $? "Install mongodb client"
mongosh --host $MONGODB_HOST </app/db/master-data.js &>>"$LOG_FILE"
VALIDATE $? "Load catalogue products"
systemctl restart catalogue
VALIDATE $? "Restarted catalogue"


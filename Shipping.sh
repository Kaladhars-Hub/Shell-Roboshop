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

# Define MySQL connection details
MYSQL_HOST="mysql.awslearning.fun"
MYSQL_USER="root"
MYSQL_PASS="RoboShop@1"

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
# DEPENDENCY INSTALLATION
# ====================

echo -e "\n${Y}=== INSTALLING MAVEN ===${N}" | tee -a "$LOG_FILE"
dnf install maven -y &>>"$LOG_FILE"
VALIDATE $? "Install Maven"

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
curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Download application"

cd /app 
unzip -o /tmp/shipping.zip &>>"$LOG_FILE"
VALIDATE $? "Extract application"

# Build the application
mvn clean package &>>"$LOG_FILE"
VALIDATE $? "Build application"
mv target/shipping-1.0.jar shipping.jar &>>"$LOG_FILE"
VALIDATE $? "Rename JAR file"

# ====================
# SERVICE SETUP
# ====================

echo -e "\n${Y}=== CONFIGURING SERVICE ===${N}" | tee -a "$LOG_FILE"

cp $SCRIPT_DIR/shipping.service /etc/systemd/system/shipping.service &>>"$LOG_FILE"
VALIDATE $? "Copy service file"

chown -R roboshop:roboshop /app &>>"$LOG_FILE"
VALIDATE $? "Set ownership"

systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Reload systemd"

systemctl enable shipping &>>"$LOG_FILE"
VALIDATE $? "Enable service"

systemctl start shipping &>>"$LOG_FILE"  
VALIDATE $? "Start service (initial)"

# ====================
# LOADING DATA INTO MYSQL
# ====================

echo -e "\n${Y}=== LOADING DATA INTO MYSQL ===${N}" | tee -a "$LOG_FILE"

# Install MySQL Client to load data
dnf install mysql -y &>>"$LOG_FILE"
VALIDATE $? "Install MySQL client"

# Step 1: Create the database
echo "Creating database 'shipping'..." | tee -a "$LOG_FILE"
mysql -h "$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "CREATE DATABASE IF NOT EXISTS shipping;" &>>"$LOG_FILE"
VALIDATE $? "Create 'shipping' database"

# Step 2: Load the schema
if [ -f /app/db/schema.sql ]; then
    echo "Loading schema..." | tee -a "$LOG_FILE"
    mysql -h "$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASS" shipping < /app/db/schema.sql &>>"$LOG_FILE"
    VALIDATE $? "Load schema.sql"
else
    echo -e "${R}/app/db/schema.sql not found... FAILURE${N}" | tee -a "$LOG_FILE"
    exit 1
fi

# Step 3: Load the master data
if [ -f /app/db/master-data.sql ]; then
    echo "Loading master data..." | tee -a "$LOG_FILE"
    mysql -h "$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASS" shipping < /app/db/master-data.sql &>>"$LOG_FILE"
    VALIDATE $? "Load master-data.sql"
else
    echo -e "${R}/app/db/master-data.sql not found... FAILURE${N}" | tee -a "$LOG_FILE"
    exit 1
fi

# Step 4: Load the app user permissions
if [ -f /app/db/app-user.sql ]; then
    echo "Loading app user..." | tee -a "$LOG_FILE"
    mysql -h "$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASS" shipping < /app/db/app-user.sql &>>"$LOG_FILE"
    VALIDATE $? "Load app-user.sql"
else
    echo -e "${R}/app/db/app-user.sql not found... FAILURE${N}" | tee -a "$LOG_FILE"
    exit 1
fi

# ====================
# FINAL RESTART
# ====================

systemctl restart shipping &>>"$LOG_FILE"
VALIDATE $? "Restart shipping service"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
echo -e "Script executed in: ${Y}${TOTAL_TIME} Seconds${N}" | tee -a "$LOG_FILE"
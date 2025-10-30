#!/bin/bash

# =============================================
# ROBOSHOP - MYSQL DATABASE SETUP SCRIPT
# =============================================

# ====================
# SECTION 1: CONFIGURATION
# ====================

USERID=$(id -u)
SCRIPT_DIR=$(pwd)
R="\e[31m"
G="\e[32m" 
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/Shell-Roboshop"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

# MySQL Configuration
MYSQL_ROOT_PASSWORD="RoboShop@1"

# ====================
# SECTION 2: INITIALIZATION
# ====================

mkdir -p "$LOGS_FOLDER"
touch "$LOG_FILE"

echo "===============================================" | tee -a "$LOG_FILE"
echo "MySQL Setup Started at: $(date)" | tee -a "$LOG_FILE"
echo "===============================================" | tee -a "$LOG_FILE"

if [ "$USERID" -ne 0 ]; then
    echo -e "${R}ERROR: Run with root privilege${N}" | tee -a "$LOG_FILE"
    exit 1
fi

# ====================
# SECTION 3: FUNCTIONS
# ====================

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
# SECTION 4: MYSQL INSTALLATION
# ====================

echo -e "\n${Y}=== INSTALLING MYSQL SERVER ===${N}" | tee -a "$LOG_FILE"

echo "Installing MySQL Server..." | tee -a "$LOG_FILE"
dnf install mysql-server -y &>>"$LOG_FILE"
VALIDATE $? "Install MySQL Server"

# ====================
# SECTION 5: MYSQL SERVICE SETUP
# ====================

echo -e "\n${Y}=== CONFIGURING MYSQL SERVICE ===${N}" | tee -a "$LOG_FILE"

echo "Enabling MySQL service..." | tee -a "$LOG_FILE"
systemctl enable mysqld &>>"$LOG_FILE"
VALIDATE $? "Enable MySQL service"

echo "Starting MySQL service..." | tee -a "$LOG_FILE"
systemctl start mysqld &>>"$LOG_FILE"
VALIDATE $? "Start MySQL service"

# ====================
# SECTION 6: DATABASE SECURITY
# ====================

echo -e "\n${Y}=== SECURING MYSQL INSTALLATION ===${N}" | tee -a "$LOG_FILE"

echo "Setting root password..." | tee -a "$LOG_FILE"
mysql_secure_installation --set-root-pass $MYSQL_ROOT_PASSWORD &>>"$LOG_FILE"

# mysql_secure_installation returns 0 even if password was already set
# So we use a different validation approach
if mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SELECT 1;" &>>"$LOG_FILE"; then
    echo -e "Set root password ... ${G}SUCCESS${N}" | tee -a "$LOG_FILE"
else
    echo -e "Set root password ... ${R}FAILURE${N}" | tee -a "$LOG_FILE"
    exit 1
fi

# ====================
# SECTION 7: DATABASE CONFIGURATION
# ====================

echo -e "\n${Y}=== CONFIGURING DATABASE ===${N}" | tee -a "$LOG_FILE"

# Allow root login from any host (for microservices communication)
echo "Configuring remote access..." | tee -a "$LOG_FILE"
mysql -uroot -p$MYSQL_ROOT_PASSWORD &>>"$LOG_FILE" <<EOF
UPDATE mysql.user SET Host='%' WHERE User='root';
FLUSH PRIVILEGES;
EOF
VALIDATE $? "Configure remote access"

# Restart MySQL to apply changes
echo "Restarting MySQL service..." | tee -a "$LOG_FILE"
systemctl restart mysqld &>>"$LOG_FILE"
VALIDATE $? "Restart MySQL service"

# ====================
# SECTION 8: COMPLETION
# ====================

echo -e "\n${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${G}✅ MYSQL INSTALLATION COMPLETED${N}" | tee -a "$LOG_FILE"
echo -e "${G}===============================================${N}" | tee -a "$LOG_FILE"
echo -e "${Y}📊 MySQL running on: 3306${N}" | tee -a "$LOG_FILE"
echo -e "${Y}🔑 Root password: $MYSQL_ROOT_PASSWORD${N}" | tee -a "$LOG_FILE"
echo -e "${Y}🌐 Remote access: Enabled${N}" | tee -a "$LOG_FILE"
echo "Completed at: $(date)" | tee -a "$LOG_FILE"
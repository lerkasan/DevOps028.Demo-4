#!/usr/bin/env bash

export JAVA_HOME="/usr/lib/jvm/java-8-oracle"
export M2_HOME="/usr/share/maven"

export DB_NAME="auradb"
export DB_USER="aura"
export DB_PASS="mysecretpassword"
export DB_HOST=`ifconfig | grep "inet addr" | grep -v -e "127.0.0.1" -e "10.0.2" | awk '{print $2}' | awk -F':' '{print $2}'`
export DB_PORT="5432"
export LOGIN_HOST="localhost"
export ALLOWED_LAN=`echo ${DB_HOST}/24`

OS_USERNAME=`whoami`
PROJECT_DIR="/home/${OS_USERNAME}/demo1"
LIQUIBASE_PATH="${PROJECT_DIR}/liquibase"
LIQUIBASE_BIN_DIR="${PROJECT_DIR}/liquibase/bin"
LIQUIBASE_PROPERTIES_TEMPLATE="${LIQUIBASE_PATH}/liquibase.properties.template"
LIQUIBASE_PROPERTIES="${LIQUIBASE_PATH}/liquibase.properties"
LIQUIBASE_URL="https://github.com/liquibase/liquibase/releases/download/liquibase-parent-3.5.3/liquibase-3.5.3-bin.tar.gz"
POSTGRES_JDBC_DRIVER_URL="https://jdbc.postgresql.org/download/postgresql-42.1.4.jar"

sed "s/%LOGIN_HOST%/${LOGIN_HOST}/g" ${LIQUIBASE_PROPERTIES_TEMPLATE} |
    sed "s/%DB_HOST%/${DB_HOST}/g" |
    sed "s/%DB_PORT%/${DB_PORT}/g" |
    sed "s/%DB_NAME%/${DB_NAME}/g" |
    sed "s/%DB_USER%/${DB_USER}/g" |
    sed "s/%DB_PASS%/${DB_PASS}/g" > ${LIQUIBASE_PROPERTIES}

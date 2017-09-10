#!/usr/bin/env bash

export JAVA_HOME="/usr/lib/jvm/java-8-oracle"
export M2_HOME="/usr/share/maven"

export PROJECT_DIR="/home/ubuntu/demo1"
export LIQUIBASE_BIN_DIR="liquibase/bin"
export LIQUIBASE_URL="https://github.com/liquibase/liquibase/releases/download/liquibase-parent-3.5.3/liquibase-3.5.3-bin.tar.gz"
export POSTGRES_JDBC_DRIVER_URL="https://jdbc.postgresql.org/download/postgresql-42.1.4.jar"

export DB_NAME="auradb"
export DB_USER="aura"
export DB_PASS="mysecretpassword"
# export DB_HOST="auradb.co7bbd9vzwhv.us-west-2.rds.amazonaws.com"
export DB_HOST=`ifconfig | grep "inet addr" | grep -v -e "127.0.0.1" -e "10.0.2" | awk '{print $2}' | awk -F':' '{print $2}'`
export DB_PORT="5432"
export LOGIN_HOST="localhost"
export ALLOWED_LAN=`echo ${DB_HOST}/24`

export RESOURCES_PATH="/home/ubuntu/demo1/src/main/resources"
APP_PROPERTIES_TEMPLATE="${RESOURCES_PATH}/application.properties.template"
APP_PROPERTIES_EXAMPLE="${RESOURCES_PATH}/application.properties.example"
APP_PROPERTIES="${RESOURCES_PATH}/application.properties"
LIQUIBASE_PATH="/home/ubuntu/demo1/liquibase"
LIQUIBASE_PROPERTIES_TEMPLATE="${LIQUIBASE_PATH}/liquibase.properties.template"
LIQUIBASE_PROPERTIES="${LIQUIBASE_PATH}/liquibase.properties"

sed "s/%LOGIN_HOST%/${LOGIN_HOST}/g" ${LIQUIBASE_PROPERTIES_TEMPLATE} |
    sed "s/%DB_HOST%/${DB_HOST}/g" |
    sed "s/%DB_PORT%/${DB_PORT}/g" |
    sed "s/%DB_NAME%/${DB_NAME}/g" |
    sed "s/%DB_USER%/${DB_USER}/g" |
    sed "s/%DB_PASS%/${DB_PASS}/g" > ${LIQUIBASE_PROPERTIES}

sed "s/%LOGIN_HOST%/${LOGIN_HOST}/g" ${APP_PROPERTIES_TEMPLATE} |
    sed "s/%DB_HOST%/${DB_HOST}/g" |
    sed "s/%DB_PORT%/${DB_PORT}/g" |
    sed "s/%DB_NAME%/${DB_NAME}/g" |
    sed "s/%DB_USER%/${DB_USER}/g" |
    sed "s/%DB_PASS%/${DB_PASS}/g" > ${APP_PROPERTIES}
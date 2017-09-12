#!/usr/bin/env bash

export DB_NAME="auradb"
export DB_USER="aura"
export DB_PASS="mysecretpassword"
# export DB_HOST="auradb.co7bbd9vzwhv.us-west-2.rds.amazonaws.com"
export DB_HOST=`ifconfig | grep "inet addr" | grep -v -e "127.0.0.1" -e "10.0.2" | awk '{print $2}' | awk -F':' '{print $2}'`
export DB_PORT="5432"
export LOGIN_HOST="localhost"

PROJECT_DIR="/home/ubuntu/demo1"

cd ${PROJECT_DIR}
mvn clean package
java -jar target/*.jar
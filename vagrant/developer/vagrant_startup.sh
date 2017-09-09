#!/usr/bin/env bash

PROJECT_DIR="/home/ubuntu/demo1"

cd ${PROJECT_DIR}
mvn clean package
java -jar target/*.jar
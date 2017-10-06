#!/usr/bin/env bash

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "SECRET_ACCESS_KEY"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "ACCESS_KEY_ID"`

export DB_NAME=`get_from_parameter_store "DB_NAME"`
export DB_USER=`get_from_parameter_store "DB_USER"`
export DB_PASS=`get_from_parameter_store "DB_PASS"`
export LOGIN_HOST="localhost"
TEST_DB_INSTANCE_ID="demo1-test"
DB_INSTANCE_ID="demo1"

APP_PROPERTIES="${WORKSPACE}/src/main/resources/application.properties"
APP_PROPERTIES_TEMPLATE="${APP_PROPERTIES}.template"

# Stop test DB instance
# aws rds stop-db-instance --db-instance-identifier ${TEST_DB_INSTANCE_ID}

# Delete test DB instance
# aws rds delete-db-instance --db-instance-identifier ${DB_INSTANCE_ID} --skip-final-snapshot
# aws rds wait db-instance-deleted --db-instance-identifier ${DB_INSTANCE_ID}

# Get prod database parameters
EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --db-instance-identifier ${DB_INSTANCE_ID} \
--query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,DBInstanceStatus]' --output text`
export DB_HOST=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $2}'`
export DB_PORT=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $3}'`

# Insert database parameters into SpringBoot application.properties
sed "s/%LOGIN_HOST%/${LOGIN_HOST}/g" ${APP_PROPERTIES_TEMPLATE} |
    sed "s/%DB_HOST%/${DB_HOST}/g" |
    sed "s/%DB_PORT%/${DB_PORT}/g" |
    sed "s/%DB_NAME%/${DB_NAME}/g" |
    sed "s/%DB_USER%/${DB_USER}/g" |
    sed "s/%DB_PASS%/${DB_PASS}/g" > ${APP_PROPERTIES}

# Change artifact packaging type to war
cd ${WORKSPACE}
sed -i "s/<name>Samsara<\/name>/<name>Samsara<\/name><packaging>war<\/packaging>/g" pom.xml

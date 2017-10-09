#!/usr/bin/env bash

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "SECRET_ACCESS_KEY"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "ACCESS_KEY_ID"`

DB_INSTANCE_ID="demo2"
DB_INSTANCE_CLASS="db.t2.micro"
DB_ENGINE="postgres"
export DB_NAME=`get_from_parameter_store "DB_NAME"`
export DB_USER=`get_from_parameter_store "DB_USER"`
export DB_PASS=`get_from_parameter_store "DB_PASS"`
export LOGIN_HOST="localhost"

# Create RDS database instance if needed
EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,DBInstanceStatus]' \
--output text | grep ${DB_INSTANCE_ID} | grep -v -e terminated -e shutting-down`
if [[ -z ${EXISTING_DB_INSTANCE_INFO} ]]; then
    echo "Creating RDS database instance ..."
    aws rds create-db-instance --db-instance-identifier ${DB_INSTANCE_ID} --db-instance-class ${DB_INSTANCE_CLASS} --engine ${DB_ENGINE} \
    --backup-retention-period 0 --storage-type gp2 --allocated-storage 5 --db-name ${DB_NAME} --master-username ${DB_USER} --master-user-password ${DB_PASS}
    aws rds wait db-instance-available --db-instance-identifier ${DB_INSTANCE_ID}
else
    # Start RDS database instance if needed
    echo "Starting RDS database instance if needed ..."
    EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --db-instance-identifier ${DB_INSTANCE_ID} \
    --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,DBInstanceStatus]' --output text`
    DB_STATUS=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $4}'`
    if [[ ${DB_STATUS} == "stopped" ]]; then
        aws rds start-db-instance --db-instance-identifier ${DB_INSTANCE_ID}
        aws rds wait db-instance-available --db-instance-identifier ${DB_INSTANCE_ID}
    fi
fi
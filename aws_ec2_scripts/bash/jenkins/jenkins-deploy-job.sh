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

DB_INSTANCE_ID="vagrantdemo1"
DB_INSTANCE_CLASS="db.t2.micro"
DB_ENGINE="postgres"

LIQUIBASE_BIN_DIR="${WORKSPACE}/liquibase/bin"
LIQUIBASE_PROPERTIES_TEMPLATE="${WORKSPACE}/liquibase/liquibase.properties.template"
LIQUIBASE_PROPERTIES="${WORKSPACE}/liquibase/liquibase.properties"

ARTIFACT_FILENAME="ROOT.war"
TOMCAT_USER=`get_from_parameter_store "TOMCAT_USER"`
TOMCAT_PASSWORD=`get_from_parameter_store "TOMCAT_PASSWORD"`
TOMCAT_PORT=8080
TOMCAT_OS="Amazon Linux"
TOMCAT_INSTANCE_TYPE="t2.micro"
TOMCAT_AVAIL_ZONE="us-west-2a"
TOMCAT_SSH_KEY_NAME="aws_ec2_2"
TOMCAT_AMI="ami-aa5ebdd2"
TOMCAT_SECURITY_GROUP="sg-7c3b9f1a"
TOMCAT_USERDATA_FILE_PATH="${WORKSPACE}/aws_ec2_scripts/bash/infra/tomcat-aws-ami-init.sh"
TOMCAT_IAM="demo1"

# Create tomcat instance if needed
TOMCAT_INSTANCE_INFO=`aws ec2 describe-instances --filters "Name=tag:Name,Values=tomcat" \
--query 'Reservations[*].Instances[*].[State.Name,InstanceId,PublicDnsName]' --output text | grep -v -e terminated -e shutting-down`
if [[ -z ${TOMCAT_INSTANCE_INFO} ]]; then
    TOMCAT_INSTANCE_ID=`aws ec2 run-instances --count 1 --instance-type ${TOMCAT_INSTANCE_TYPE} --image-id ${TOMCAT_AMI} --key-name ${TOMCAT_SSH_KEY_NAME} \
    --security-group-ids ${TOMCAT_SECURITY_GROUP} --user-data "file://${TOMCAT_USERDATA_FILE_PATH}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=tomcat}]" --iam-instance-profile Name=${TOMCAT_IAM} \
    --disable-api-termination | grep INSTANCES | awk '{print $7}'`
    aws ec2 wait instance-running --instance-ids ${TOMCAT_INSTANCE_ID}
    aws ec2 wait instance-status-ok --instance-ids ${TOMCAT_INSTANCE_ID} --filters "Name=instance-status.reachability,Values=passed"
    sleep 180
else
    # Start tomcat instance if needed
    TOMCAT_STATE=`echo ${TOMCAT_INSTANCE_INFO} | awk '{print $1}'`
    TOMCAT_INSTANCE_ID=`echo ${TOMCAT_INSTANCE_INFO} | awk '{print $2}'`
    if [[ ${TOMCAT_STATE} == "stopped" ]]; then
        aws ec2 start-instances --instance-ids ${TOMCAT_INSTANCE_ID}
        aws ec2 wait instance-running --instance-ids ${TOMCAT_INSTANCE_ID}
        aws ec2 wait instance-status-ok --instance-ids ${TOMCAT_INSTANCE_ID} --filters "Name=instance-status.reachability,Values=passed"
        sleep 180
    fi
fi
export TOMCAT_HOST=`aws ec2 describe-instances --instance-ids ${TOMCAT_INSTANCE_ID} --filters "Name=tag:Name,Values=tomcat" \
--query 'Reservations[*].Instances[*].[State.Name,InstanceId,PublicDnsName]'  --output text | awk '{print $3}' | grep -v -e terminated -e shutting-down | grep amazon`

EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --db-instance-identifier ${DB_INSTANCE_ID} \
--query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,DBInstanceStatus]' --output text`

# Start database instance if needed
DB_STATUS=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $4}'`
if [[ ${DB_STATUS} == "stopped" ]]; then
    aws rds start-db-instance --db-instance-identifier ${DB_INSTANCE_ID}
    aws rds wait db-instance-available --db-instance-identifier ${DB_INSTANCE_ID}
fi
export DB_HOST=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $2}'`
export DB_PORT=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $3}'`


# Update database using Liquibase
sed "s/%LOGIN_HOST%/${LOGIN_HOST}/g" ${LIQUIBASE_PROPERTIES_TEMPLATE} |
    sed "s/%DB_HOST%/${DB_HOST}/g" |
    sed "s/%DB_PORT%/${DB_PORT}/g" |
    sed "s/%DB_NAME%/${DB_NAME}/g" |
    sed "s/%DB_USER%/${DB_USER}/g" |
    sed "s/%DB_PASS%/${DB_PASS}/g" > ${LIQUIBASE_PROPERTIES}

echo "Database URL ${DB_HOST}:${DB_PORT}"

cd ${LIQUIBASE_BIN_DIR}
./liquibase --changeLogFile=../changelogs/changelog-main.xml --defaultsFile=../liquibase.properties update

# Deploy Java application to remote Tomcat
curl "http://${TOMCAT_USER}:${TOMCAT_PASSWORD}@${TOMCAT_HOST}:${TOMCAT_PORT}/manager/text/undeploy?path=/"
curl --upload-file ${WORKSPACE}/target/${ARTIFACT_FILENAME} "http://${TOMCAT_USER}:${TOMCAT_PASSWORD}@${TOMCAT_HOST}:${TOMCAT_PORT}/manager/text/deploy?path=/&war=file:/home/ec2-user/ROOT.war"

HTTP_CODE=`curl -s -o /dev/null -w "%{http_code}" "http://${TOMCAT_HOST}:${TOMCAT_PORT}"`
if [[ ${HTTP_CODE} > 399 ]]; then
	echo "HTTP_RESPONSE_CODE = ${HTTP_CODE}"
	exit 1
fi

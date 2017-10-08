#!/usr/bin/env bash

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "SECRET_ACCESS_KEY"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "ACCESS_KEY_ID"`

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
TOMCAT_USERDATA_FILE_PATH="${WORKSPACE}/jenkins/infra/tomcat-aws-ami-init.sh"
TOMCAT_IAM="demo1"
TOMCAT_INSTALL_DIR="/opt/tomcat"
TOMCAT_VERSION="8.5.20"

# Create tomcat instance if needed
TOMCAT_INSTANCE_INFO=`aws ec2 describe-instances --filters "Name=tag:Name,Values=tomcat" \
--query 'Reservations[*].Instances[*].[State.Name,InstanceId,PublicDnsName]' --output text | grep -v -e terminated -e shutting-down`
if [[ -z ${TOMCAT_INSTANCE_INFO} ]]; then
    TOMCAT_INSTANCE_ID=`aws ec2 run-instances --count 1 --instance-type ${TOMCAT_INSTANCE_TYPE} --image-id ${TOMCAT_AMI} --key-name ${TOMCAT_SSH_KEY_NAME} \
    --security-group-ids ${TOMCAT_SECURITY_GROUP} --user-data "file://${TOMCAT_USERDATA_FILE_PATH}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=tomcat}]" --iam-instance-profile Name=${TOMCAT_IAM} \
    --disable-api-termination | grep INSTANCES | awk '{print $7}'`
    aws ec2 wait instance-running --instance-ids ${TOMCAT_INSTANCE_ID}
    # aws ec2 wait instance-status-ok --instance-ids ${TOMCAT_INSTANCE_ID} --filters "Name=instance-status.reachability,Values=passed"
    sleep 30
else
    # Start tomcat instance if needed
    TOMCAT_STATE=`echo ${TOMCAT_INSTANCE_INFO} | awk '{print $1}'`
    TOMCAT_INSTANCE_ID=`echo ${TOMCAT_INSTANCE_INFO} | awk '{print $2}'`
    if [[ ${TOMCAT_STATE} == "stopped" ]]; then
        aws ec2 start-instances --instance-ids ${TOMCAT_INSTANCE_ID}
        aws ec2 wait instance-running --instance-ids ${TOMCAT_INSTANCE_ID}
        # aws ec2 wait instance-status-ok --instance-ids ${TOMCAT_INSTANCE_ID} --filters "Name=instance-status.reachability,Values=passed"
        sleep 30
    fi
fi
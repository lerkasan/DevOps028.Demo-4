#!/usr/bin/env bash

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "SECRET_ACCESS_KEY"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "ACCESS_KEY_ID"`

OS="Amazon Linux"
INSTANCE_TYPE="t2.micro"
AVAIL_ZONE="us-west-2a"
SSH_KEY_NAME="aws_ec2_2"
AMI="ami-aa5ebdd2"
SECURITY_GROUP="sg-7c3b9f1a"
USERDATA_FILE_PATH="${WORKSPACE}/jenkins/job-dsl/slave-node-userdata.sh"
IAM="demo1"

# Create slave node instance if needed
INSTANCES_INFO=`aws ec2 describe-instances --filters "Name=tag:Name,Values=jenkins-slave" \
--query 'Reservations[*].Instances[*].[State.Name,InstanceId,PublicDnsName]' --output text | grep -v -e terminated -e shutting-down`
if [[ -z ${INSTANCES_INFO} ]]; then
    INSTANCE_IDS=`aws ec2 run-instances --count 2 --instance-type ${INSTANCE_TYPE} --image-id ${AMI} --key-name ${SSH_KEY_NAME} \
    --security-group-ids ${SECURITY_GROUP} --user-data "file://${USERDATA_FILE_PATH}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=jenkins-slave}]" --iam-instance-profile Name=${IAM} \
    --disable-api-termination | grep INSTANCES | awk '{print $7}' | tr '\n' ' '`
    sleep 100
    aws ec2 wait instance-running --instance-ids ${INSTANCE_IDS}
    # aws ec2 wait instance-status-ok --instance-ids ${INSTANCE_ID} --filters "Name=instance-status.reachability,Values=passed"
else
    # Start slave node instances if needed
    for INSTANCE_INFO in ${INSTANCES_INFO}; do
        INSTANCE_STATE=`echo ${INSTANCE_INFO} | awk '{print $1}'`
        INSTANCE_ID=`echo ${INSTANCE_INFO} | awk '{print $2}'`
        if [[ ${INSTANCE_STATE} == "stopped" ]]; then
            aws ec2 start-instances --instance-ids ${INSTANCE_ID}
            sleep 100
            aws ec2 wait instance-running --instance-ids ${INSTANCE_ID}
            # aws ec2 wait instance-status-ok --instance-ids ${INSTANCE_ID} --filters "Name=instance-status.reachability,Values=passed"
        fi
    done
fi
#!/usr/bin/env bash

OS="Amazon Linux"
INSTANCE_TYPE="t2.micro"
AVAIL_ZONE="us-west-2a"
SSH_KEY_NAME="demo2_webapp"
AMI="ami-e689729e"
SECURITY_GROUP="sg-7c3b9f1a"
USERDATA_FILE_PATH="${WORKSPACE}/jenkins/slave-nodes/slave-node-userdata.sh"
IAM="demo2_jenkins_instance"

# Create slave node instance if needed
INSTANCES_INFO=`aws ec2 describe-instances --filters "Name=tag:Name,Values=jenkins-slaves" \
--query 'Reservations[*].Instances[*].[State.Name,InstanceId,PublicDnsName]' --output text | grep -v -e terminated -e shutting-down`
if [[ -z ${INSTANCES_INFO} ]]; then
    INSTANCE_IDS=`aws ec2 run-instances --count 2 --instance-type ${INSTANCE_TYPE} --image-id ${AMI} --key-name ${SSH_KEY_NAME} \
    --security-group-ids ${SECURITY_GROUP} --user-data "file://${USERDATA_FILE_PATH}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=jenkins-slaves}]" --iam-instance-profile Name=${IAM} \
    --disable-api-termination | grep INSTANCES | awk '{print $7}' | tr '\n' ' '`
    echo "Waiting 60 seconds while slave nodes are starting ..."
    sleep 60
    # aws ec2 wait instance-running --instance-ids ${INSTANCE_IDS}
    # aws ec2 wait instance-status-ok --instance-ids ${INSTANCE_ID} --filters "Name=instance-status.reachability,Values=passed"
else
    # Start slave node instances if needed
    for INSTANCE_INFO in ${INSTANCES_INFO}; do
        INSTANCE_STATE=`echo ${INSTANCE_INFO} | awk '{print $1}'`
        INSTANCE_ID=`echo ${INSTANCE_INFO} | awk '{print $2}'`
        if [[ ${INSTANCE_STATE} == "stopped" ]]; then
            aws ec2 start-instances --instance-ids ${INSTANCE_ID}
            echo "Waiting 60 seconds while slave nodes are starting ..."
            sleep 60
            # aws ec2 wait instance-running --instance-ids ${INSTANCE_ID}
            # aws ec2 wait instance-status-ok --instance-ids ${INSTANCE_ID} --filters "Name=instance-status.reachability,Values=passed"
        fi
    done
fi
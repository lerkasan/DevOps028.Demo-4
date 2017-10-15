#!/usr/bin/env bash

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "SECRET_ACCESS_KEY"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "ACCESS_KEY_ID"`

INSTANCES_INFO=`aws ec2 describe-instances --filters "Name=tag:Name,Values=jenkins-slaves" \
--query 'Reservations[*].Instances[*].[State.Name,InstanceId,PublicDnsName]' --output text | grep -v -e terminated -e shutting-down`

# Stop each slave node instance if needed
for INSTANCE_INFO in ${INSTANCES_INFO}; do
    INSTANCE_STATE=`echo ${INSTANCE_INFO} | awk '{print $1}'`
    INSTANCE_ID=`echo ${INSTANCE_INFO} | awk '{print $2}'`
    if [[ ${INSTANCE_STATE} == "running" ]]; then
        aws ec2 stop-instances --instance-ids ${INSTANCE_ID}
    fi
done

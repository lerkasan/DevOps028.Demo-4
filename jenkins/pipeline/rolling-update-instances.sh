#!/usr/bin/env bash

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

#export AWS_DEFAULT_REGION="us-west-2"
#export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "jenkins_secret_access_key"`
#export AWS_ACCESS_KEY_ID=`get_from_parameter_store "jenkins_access_key_id"`

#AUTOSCALEGROUP_NAME=`get_from_parameter_store "demo2_autoscalegroup_name"`
MAX_SIZE=3
let TMP_MAX_SIZE=${MAX_SIZE}*2

# Force ASG to create new instances that will download new jar executing userdata
echo "Creating new EC2 instances in autoscaling group with the latest webapp version ..."
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${AUTOSCALEGROUP_NAME} --max-size ${TMP_MAX_SIZE} --desired-capacity ${TMP_MAX_SIZE} --termination-policies "OldestInstance"
sleep 60
# Force ASG to delete old instances running old jar
echo "Deleting old EC2 instances in autoscaling group with previous webapp version ..."
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${AUTOSCALEGROUP_NAME} --max-size ${MAX_SIZE} --desired-capacity ${MAX_SIZE}
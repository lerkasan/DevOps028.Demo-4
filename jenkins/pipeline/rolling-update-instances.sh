#!/usr/bin/env bash

MAX_SIZE=3
let TMP_MAX_SIZE=${MAX_SIZE}*2

# Force ASG to create new instances that will download new jar executing userdata
echo "Creating new EC2 instances in autoscaling group with the latest webapp version ..."
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${TF_VAR_autoscalegroup_name} --max-size ${TMP_MAX_SIZE} --desired-capacity ${TMP_MAX_SIZE} --termination-policies "OldestInstance"
sleep 60
# Force ASG to delete old instances running old jar
echo "Deleting old EC2 instances in autoscaling group with previous webapp version ..."
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${TF_VAR_autoscalegroup_name} --max-size ${MAX_SIZE} --desired-capacity ${MAX_SIZE}
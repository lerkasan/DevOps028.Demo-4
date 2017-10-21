#!/usr/bin/env bash
# Instead of terraform destroy

# Requires one argument:
# string $1 - name of parameter in EC2 parameter store
function get_from_parameter_store {
    aws ssm get-parameter --name $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "jenkins_secret_access_key"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "jenkins_access_key_id"`

DB_INSTANCE_ID=`get_from_parameter_store "demo2_rds_identifier"`

aws elb delete-load-balancer --load-balancer-name "demo2-elb"
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "demo2-autoscalegroup" --force-delete
aws rds delete-db-instance --db-instance-identifier "${DB_INSTANCE_ID}" --skip-final-snapshot
echo "Waiting 5 minutes for autoscaling group with EC2 instances and RDS instance to be deleted before removing autscaling launch configuration and RDS subnet group ..."
sleep 300
aws autoscaling delete-launch-configuration --launch-configuration-name "demo2_launch_configuration"
aws rds delete-db-subnet-group --db-subnet-group-name "demo2_db_subnet_group"
echo "ELB, ASG, launch configuration, RDS and RDS subnet_group were deleted. Don't forget to DELETE VPC MANUALLY."

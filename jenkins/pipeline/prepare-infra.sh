#!/usr/bin/env bash
set -e

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

#export AWS_DEFAULT_REGION="us-west-2"
#export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "jenkins_secret_access_key"`
#export AWS_ACCESS_KEY_ID=`get_from_parameter_store "jenkins_access_key_id"`

#export TF_VAR_rds_identifier=`get_from_parameter_store "demo2_rds_identifier"`
export TF_VAR_db_name=`get_from_parameter_store "demo2_db_name"`
export TF_VAR_db_user=`get_from_parameter_store "demo2_db_user"`
export TF_VAR_db_pass=`get_from_parameter_store "demo2_db_pass"`
#export TF_VAR_bucket_name=`get_from_parameter_store "demo2_bucket_name"`
#export TF_VAR_webapp_port=`get_from_parameter_store "demo2_webapp_port"`
#export TF_VAR_elb_name=`get_from_parameter_store "demo2_elb_name"`
#export TF_VAR_autoscalegroup_name=`get_from_parameter_store "demo2_autoscalegroup_name"`

cd "${WORKSPACE}/jenkins/jenkins/infra/initial"
#/home/ec2-user/terraform init -backend-config backend.tf -backend=true -force-copy
echo "Bucket name is: ${BUCKET_NAME}"
/home/ec2-user/terraform init -backend-config="bucket=${BUCKET_NAME}" -backend-config="key=terraform.tfstate" \
                              -backend-config="region=${AWS_DEFAULT_REGION}" -backend=true -force-copy -get=true -input=false
/home/ec2-user/terraform refresh
/home/ec2-user/terraform plan --out infra-plan
/home/ec2-user/terraform apply "infra-plan"
/home/ec2-user/terraform show

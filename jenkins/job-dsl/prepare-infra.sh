#!/usr/bin/env bash
set -e

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "jenkins_secret_access_key"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "jenkins_access_key_id"`

export TF_VAR_db_name=`get_from_parameter_store "DB_NAME"`
export TF_VAR_db_user=`get_from_parameter_store "DB_USER"`
export TF_VAR_db_pass=`get_from_parameter_store "DB_PASS"`

cd "${WORKSPACE}/jenkins/jenkins/infra/terraform"
/home/ec2-user/terraform init
/home/ec2-user/terraform plan --out infra-plan
/home/ec2-user/terraform apply "infra-plan"
/home/ec2-user/terraform show

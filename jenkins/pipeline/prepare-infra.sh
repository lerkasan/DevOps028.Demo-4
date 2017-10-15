#!/usr/bin/env bash
set -e

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

export TF_VAR_db_name=`get_from_parameter_store "demo2_db_name"`
export TF_VAR_db_user=`get_from_parameter_store "demo2_db_user"`
export TF_VAR_db_pass=`get_from_parameter_store "demo2_db_pass"`

cd "${WORKSPACE}/jenkins/jenkins/infra/initial"
# /home/ec2-user/terraform init -backend-config backend.tf -backend=true -force-copy
/home/ec2-user/terraform init -backend-config="bucket=${TF_VAR_bucket_name}" -backend-config="key=terraform.tfstate" \
                              -backend-config="region=${AWS_DEFAULT_REGION}" -backend=true -force-copy -get=true -input=false
/home/ec2-user/terraform refresh
/home/ec2-user/terraform plan --out infra-plan
/home/ec2-user/terraform apply "infra-plan"
/home/ec2-user/terraform show

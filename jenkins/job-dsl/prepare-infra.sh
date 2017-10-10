#!/usr/bin/env bash

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "SECRET_ACCESS_KEY"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "ACCESS_KEY_ID"`

export TF_VAR_db_name=`get_from_parameter_store "DB_NAME"`
export TF_VAR_db_user=`get_from_parameter_store "DB_USER"`
export TF_VAR_db_pass=`get_from_parameter_store "DB_PASS"`

cd "${WORKSPACE}/jenkins/jenkins/infra/terraform"
terraform init
terraform plan
terraform apply
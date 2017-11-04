#!/usr/bin/env bash
set -e

cd "${WORKSPACE}/terraform"
chmod +x ./*.sh
#/home/ec2-user/terraform init -backend-config=backend.tf -backend=true -force-copy -get=true -input=false
/home/ec2-user/terraform init -backend-config="bucket=${TF_VAR_bucket_name}" -backend-config="key=terraform/terraform.tfstate" \
                              -backend-config="region=${AWS_DEFAULT_REGION}" -backend=true -force-copy -get=true -input=false
/home/ec2-user/terraform refresh
/home/ec2-user/terraform plan --out infra-plan
/home/ec2-user/terraform apply "infra-plan"
/home/ec2-user/terraform show

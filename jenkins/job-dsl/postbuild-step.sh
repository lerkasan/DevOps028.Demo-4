#!/usr/bin/env bash

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "jenkins_secret_access_key"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "jenkins_access_key_id"`

BUCKET_NAME="ansible-demo1"
ARTIFACT_FILENAME=`ls ${WORKSPACE}/target | grep jar | grep -v original`

# Copy artifact to S3 bucket
echo "Copying artifact to S3 bucket ..."
aws s3 cp ${WORKSPACE}/target/${ARTIFACT_FILENAME} s3://${BUCKET_NAME}/${ARTIFACT_FILENAME}
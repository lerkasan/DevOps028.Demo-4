#!/usr/bin/env bash

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "SECRET_ACCESS_KEY"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "ACCESS_KEY_ID"`

ARTIFACT_FILENAME=`ls ${WORKSPACE}/target | grep war | grep -v original`
aws s3 cp ${WORKSPACE}/target/${ARTIFACT_FILENAME} s3://${BUCKET_NAME}/${ARTIFACT_FILENAME}
mv ${WORKSPACE}/target/${ARTIFACT_FILENAME} ${WORKSPACE}/target/ROOT.war
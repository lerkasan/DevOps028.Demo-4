#!/usr/bin/env bash

# Requires one argument:
# string $1 - name of parameter in EC2 parameter store
function get_from_parameter_store {
    aws ssm get-parameter --name $1 --with-decryption --output text | awk '{print $4}'
}

# Requires three arguments:
# string $1 - URL of file to be downloaded
# string $2 - full path to folder where downloaded file should be saved
# int $3    - number of download retries
function download_from_s3 {
    let RETRIES=$3
    until [ ${RETRIES} -lt 0 ] || [ -e "$2" ]; do
        aws s3 cp $1 $2
        let "RETRIES--"
        sleep 5
    done
    if [ ! -e "$2" ]; then
        echo "An error occurred during downloading file by URL $1"
        exit 1
    fi
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "webapp_secret_access_key"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "webapp_access_key_id"`

export DB_NAME=`get_from_parameter_store "demo2_db_name"`
export DB_USER=`get_from_parameter_store "demo2_db_user"`
export DB_PASS=`get_from_parameter_store "demo2_db_pass"`
export LOGIN_HOST="localhost"

BUCKET_NAME=`get_from_parameter_store "demo2_bucket_name"`
DB_INSTANCE_ID=`get_from_parameter_store "demo2_rds_identifier"`
OS_USERNAME="ec2-user"
DEMO_DIR="demo2"

JDK_FILENAME="jdk-8u144-linux-x64.tar.gz"
JDK_URL="s3://${BUCKET_NAME}/tools/${JDK_FILENAME}"
JDK_INSTALL_DIR="/usr/lib/jvm"

PROJECT_DIR="/home/${OS_USERNAME}/demo2"
WEB_APP_FILENAME=`get_from_parameter_store "demo2_artifact_filename"`
WEB_APP_URL="s3://${BUCKET_NAME}/artifacts/${WEB_APP_FILENAME}"
TEMP_DIR="/home/${OS_USERNAME}/tmp"
DOWNLOAD_DIR="/home/${OS_USERNAME}/${DEMO_DIR}/download"
DOWNLOAD_RETRIES=5

# Install Python-Pip, AWS cli
sudo yum -y update
sudo yum -y install epel-release
sudo yum -y install python python-pip mc
sudo `which pip` install --upgrade pip
sudo `which pip` install awscli

# Download and install JDK
mkdir -p ${DOWNLOAD_DIR}
sudo mkdir -p ${JDK_INSTALL_DIR}
if [ ! -e "${DOWNLOAD_DIR}/${JDK_FILENAME}" ]; then
    download_from_s3 "${JDK_URL}" "${DOWNLOAD_DIR}/${JDK_FILENAME}" ${DOWNLOAD_RETRIES}
fi
if [ -e "${DOWNLOAD_DIR}/${JDK_FILENAME}" ]; then
    sudo tar -xzf "${DOWNLOAD_DIR}/${JDK_FILENAME}" -C "${JDK_INSTALL_DIR}"
fi

export JAVA_HOME=`find ${JDK_INSTALL_DIR} -name java | grep -v -e "openjdk" -e "jre" | head -n 1 | rev | cut -c 10- | rev`
export PATH=${JAVA_HOME}/bin:${PATH}

sudo alternatives --install /usr/bin/java java "${JAVA_HOME}/bin/java" 200
sudo alternatives --install /usr/bin/javac javac "${JAVA_HOME}/bin/javac" 200
sudo alternatives --set java "${JAVA_HOME}/bin/java"
sudo alternatives --set javac "${JAVA_HOME}/bin/javac"

# Download Webapp artifact
mkdir -p ${PROJECT_DIR}
if [ ! -e "${PROJECT_DIR}/${WEB_APP_FILENAME}" ]; then
    download_from_s3 "${WEB_APP_URL}" "${PROJECT_DIR}/${WEB_APP_FILENAME}" ${DOWNLOAD_RETRIES}
fi

# Obtain RDS database host and port
echo "Obtaining RDS database endpoint ..."
EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --db-instance-identifier ${DB_INSTANCE_ID} \
    --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,DBInstanceStatus]' --output text`
MAX_RETRIES_TO_GET_DBINFO=20
RETRIES=0
while [[ -z `echo ${EXISTING_DB_INSTANCE_INFO} | grep "amazonaws"` ]] && [ ${RETRIES} -lt ${MAX_RETRIES_TO_GET_DBINFO} ]; do
    sleep 20
    EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --db-instance-identifier ${DB_INSTANCE_ID} \
    --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,DBInstanceStatus]' --output text`
    echo "Try: ${RETRIES}    DBinfo: ${EXISTING_DB_INSTANCE_INFO}"
    let "RETRIES++"
done
if [[ -z `echo ${EXISTING_DB_INSTANCE_INFO} | grep "amazonaws"` ]]; then
    echo "Failure - no RDS database with identifier ${DB_INSTANCE_ID} available."
    exit 1
fi

aws rds wait db-instance-available --db-instance-identifier ${DB_INSTANCE_ID}
export DB_HOST=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $2}'`
export DB_PORT=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $3}'`
echo "RDS endpoint: ${DB_HOST}:${DB_PORT}  Retries: ${RETRIES}"

#Run Java application
java -jar "${PROJECT_DIR}/${WEB_APP_FILENAME}"

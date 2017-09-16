#!/usr/bin/env bash
#set -e

export AWS_ACCESS_KEY_ID="------------CHANGE_ME---------------"
export AWS_SECRET_ACCESS_KEY="-----------CHANGE_ME---------------"
export AWS_DEFAULT_REGION="us-west-2"

export DB_NAME="auradb"
export DB_USER="aura"
export DB_PASS="mysecretpassword"
export LOGIN_HOST="localhost"

DB_INSTANCE_ID="demo1"
DB_INSTANCE_CLASS="db.t2.micro"
DB_ENGINE="postgres"

BUCKET_NAME="ansible-demo1"
OS_USERNAME=`whoami`
PROJECT_DIR="/home/${OS_USERNAME}/demo1"
WEB_APP_FILENAME="Samsara-1.3.5.RELEASE.jar"
WEB_APP_URL="s3://${BUCKET_NAME}/${WEB_APP_FILENAME}"

JRE_FILENAME="jre-8u144-linux-x64.tar.gz"
JRE_URL="s3://${BUCKET_NAME}/${JRE_FILENAME}"
JRE_DOWNLOAD_DIR="/usr/lib/jvm/downloaded"

LIQUIBASE_PATH="${PROJECT_DIR}/liquibase"
LIQUIBASE_BIN_DIR="${LIQUIBASE_PATH}/bin"
LIQUIBASE_PROPERTIES_TEMPLATE="${LIQUIBASE_PATH}/liquibase.properties.template"
LIQUIBASE_PROPERTIES="${LIQUIBASE_PATH}/liquibase.properties"
LIQUIBASE_FILENAME="liquibase-3.5.3-bin.tar.gz"
LIQUIBASE_URL="s3://${BUCKET_NAME}/${LIQUIBASE_FILENAME}"
LIQUIBASE_CHANGELOG_FILENAME="liquibase-changelog.tar.gz"
LIQUIBASE_CHANGELOG_URL="s3://${BUCKET_NAME}/${LIQUIBASE_CHANGELOG_FILENAME}"

POSTGRES_JDBC_DRIVER_FILENAME="postgresql-42.1.4.jar"
POSTGRES_JDBC_DRIVER_URL="s3://${BUCKET_NAME}/${POSTGRES_JDBC_DRIVER_FILENAME}"

DOWNLOAD_RETRIES=5

function download_from_s3 {
    let RETRIES=$3
    until [ ${RETRIES} -lt 0 ] || [ -e "$2" ]; do
        aws s3 cp $1 $2
        let "RETRIES--"
        sleep 10
    done
    if [ ! -e "$2" ]; then
        echo "An error occurred during downloading file by URL $1"
        exit 1
    fi
}

# Install Python-PIP, AWS-cli
sudo yum -y update
sudo yum -y install python-pip mc
pip install --upgrade pip
pip install awscli

# Create database and db_user
EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port]' --output text | grep ${DB_INSTANCE_ID}`
if [[ -z ${EXISTING_DB_INSTANCE_INFO} ]]; then
    aws rds create-db-instance --db-instance-identifier ${DB_INSTANCE_ID} --db-instance-class ${DB_INSTANCE_CLASS} --engine ${DB_ENGINE} --backup-retention-period 0 --allocated-storage 5 --db-name ${DB_NAME} --master-username ${DB_USER} --master-user-password ${DB_PASS}
    aws rds wait db-instance-available --db-instance-identifier ${DB_INSTANCE_ID}
fi
EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port]' --output text | grep ${DB_INSTANCE_ID}`
export DB_HOST=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $2}'`
export DB_PORT=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $3}'`

# Download and install JRE
sudo mkdir -p ${JRE_DOWNLOAD_DIR}
if [ ! -e "${PROJECT_DIR}/${JRE_FILENAME}" ]; then
    download_from_s3 "${JRE_URL}" "${PROJECT_DIR}/${JRE_FILENAME}" ${DOWNLOAD_RETRIES}
fi
if [ -e "${PROJECT_DIR}/${JRE_FILENAME}" ]; then
    sudo tar -xzf "${PROJECT_DIR}/${JRE_FILENAME}" -C "${JRE_DOWNLOAD_DIR}"
fi
export JAVA_HOME=`find ${JRE_DOWNLOAD_DIR} -name java | grep -v openjdk | head -n 1 | rev | cut -c 10- | rev`
export PATH=$JAVA_HOME:$PATH
sudo alternatives --install /usr/bin/java java "${JAVA_HOME}/bin/java" 2
sudo alternatives --set java "${JAVA_HOME}/bin/java"

# Download Web app
mkdir -p ${PROJECT_DIR}
if [ ! -e "${PROJECT_DIR}/${WEB_APP_FILENAME}" ]; then
    download_from_s3 "${WEB_APP_URL}" "${PROJECT_DIR}/${WEB_APP_FILENAME}" ${DOWNLOAD_RETRIES}
fi

# Download Liquibase changelog
if [ ! -e "${LIQUIBASE_BIN_DIR}/${LIQUIBASE_CHANGELOG_FILENAME}" ]; then
    download_from_s3 "${LIQUIBASE_CHANGELOG_URL}" "${PROJECT_DIR}/${LIQUIBASE_CHANGELOG_FILENAME}" ${DOWNLOAD_RETRIES}
    if [ -e "${PROJECT_DIR}/${LIQUIBASE_CHANGELOG_FILENAME}" ]; then
        tar -xzf "${PROJECT_DIR}/${LIQUIBASE_CHANGELOG_FILENAME}" -C "${PROJECT_DIR}"
    fi
fi

# Download Liquibase binaries and PostgreSQL JDBC driver
mkdir -p ${LIQUIBASE_BIN_DIR}
if [ ! -e "${LIQUIBASE_BIN_DIR}/${LIQUIBASE_FILENAME}" ]; then
    download_from_s3 "${LIQUIBASE_URL}" "${LIQUIBASE_BIN_DIR}/${LIQUIBASE_FILENAME}" ${DOWNLOAD_RETRIES}
    if [ -e "${LIQUIBASE_BIN_DIR}/${LIQUIBASE_FILENAME}" ]; then
        tar -xzf "${LIQUIBASE_BIN_DIR}/${LIQUIBASE_FILENAME}" -C "${LIQUIBASE_BIN_DIR}"
    fi
fi

if [ ! -e "${LIQUIBASE_BIN_DIR}/lib/${POSTGRES_JDBC_DRIVER_FILENAME}" ]; then
    download_from_s3 "${POSTGRES_JDBC_DRIVER_URL}" "${LIQUIBASE_BIN_DIR}/lib/${POSTGRES_JDBC_DRIVER_FILENAME}" ${DOWNLOAD_RETRIES}
fi

# Update database using Liquibase
sed "s/%LOGIN_HOST%/${LOGIN_HOST}/g" ${LIQUIBASE_PROPERTIES_TEMPLATE} |
    sed "s/%DB_HOST%/${DB_HOST}/g" |
    sed "s/%DB_PORT%/${DB_PORT}/g" |
    sed "s/%DB_NAME%/${DB_NAME}/g" |
    sed "s/%DB_USER%/${DB_USER}/g" |
    sed "s/%DB_PASS%/${DB_PASS}/g" > ${LIQUIBASE_PROPERTIES}

cd ${LIQUIBASE_BIN_DIR}
./liquibase --changeLogFile=../changelogs/changelog-main.xml --defaultsFile=../liquibase.properties update

#Run Java application
java -jar "${PROJECT_DIR}/${WEB_APP_FILENAME}"

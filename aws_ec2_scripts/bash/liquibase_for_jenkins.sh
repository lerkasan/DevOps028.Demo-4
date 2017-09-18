#!/usr/bin/env bash

export AWS_ACCESS_KEY_ID="---------------CHANGE_ME---------------"
export AWS_SECRET_ACCESS_KEY="-----------CHANGE_ME---------------"
export AWS_DEFAULT_REGION="us-west-2"

DB_INSTANCE_ID="demo1"
export DB_NAME="auradb"
export DB_USER="aura"
export DB_PASS="mysecretpassword"
export LOGIN_HOST="localhost"
EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port]' --output text | grep ${DB_INSTANCE_ID}`
export DB_HOST=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $2}'`
export DB_PORT=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $3}'`

BUCKET_NAME="ansible-demo1"
LIQUIBASE_BIN_DIR="${WORKSPACE}/liquibase/bin"
LIQUIBASE_FILENAME="liquibase-3.5.3-bin.tar.gz"
LIQUIBASE_URL="s3://${BUCKET_NAME}/${LIQUIBASE_FILENAME}"
LIQUIBASE_PROPERTIES_TEMPLATE="${WORKSPACE}/liquibase/liquibase.properties.template"
LIQUIBASE_PROPERTIES="${WORKSPACE}/liquibase/liquibase.properties"
APP_PROPERTIES="${WORKSPACE}/src/resources/application.properties"
APP_PROPERTIES_TEMPLATE="${APP_PROPERTIES}.template"

POSTGRES_JDBC_DRIVER_FILENAME="postgresql-42.1.4.jar"
POSTGRES_JDBC_DRIVER_URL="s3://${BUCKET_NAME}/${POSTGRES_JDBC_DRIVER_FILENAME}"

DOWNLOAD_RETRIES=5

TOMCAT_USER="tomcat"
TOMCAT_PASSWORD="Rn7xU3kD2t"
export TOMCAT_HOST=`aws ec2 describe-instances --filters "Name=tag:Name,Values=tomcat" --query 'Reservations[*].Instances[*].[PublicDnsName,Tags[*]]'  --output text | grep amazon`

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

sed "s/%LOGIN_HOST%/${LOGIN_HOST}/g" ${APP_PROPERTIES_TEMPLATE} |
    sed "s/%DB_HOST%/${DB_HOST}/g" |
    sed "s/%DB_PORT%/${DB_PORT}/g" |
    sed "s/%DB_NAME%/${DB_NAME}/g" |
    sed "s/%DB_USER%/${DB_USER}/g" |
    sed "s/%DB_PASS%/${DB_PASS}/g" > ${APP_PROPERTIES}

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

# Build war package
cd ${WORKSPACE}
sed -i "s/<name>Samsara<\/name>/<name>Samsara<\/name><packaging>war<\/packaging>/g" pom.xml
mvn clean package
ARTIFACT_FILENAME=`ls target | grep war | grep -v original`
echo "Tomcat URL = ${TOMCAT_HOST}:8080"

# Deploy Java application to remote Tomcat
curl "http://${TOMCAT_USER}:${TOMCAT_PASSWORD}@${TOMCAT_HOST}:8080/manager/text/undeploy?path=/"
curl "http://${TOMCAT_USER}:${TOMCAT_PASSWORD}@${TOMCAT_HOST}:8080/manager/text/deploy?path=/&war=file:${WORKSPACE}/target/${ARTIFACT_FILENAME}"

# Run Java application
# java -jar ../target/*.jar

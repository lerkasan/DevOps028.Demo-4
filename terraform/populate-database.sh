#!/usr/bin/env bash
# set -e

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

export DB_NAME=`get_from_parameter_store "demo2_db_name"`
export DB_USER=`get_from_parameter_store "demo2_db_user"`
export DB_PASS=`get_from_parameter_store "demo2_db_pass"`
export LOGIN_HOST="localhost"

LIQUIBASE_BIN_DIR="${WORKSPACE}/liquibase/bin"
LIQUIBASE_FILENAME="liquibase-3.5.3-bin.tar.gz"
LIQUIBASE_URL="s3://${TF_VAR_bucket_name}/tools/${LIQUIBASE_FILENAME}"
LIQUIBASE_PROPERTIES_TEMPLATE="${WORKSPACE}/liquibase/liquibase.properties.template"
LIQUIBASE_PROPERTIES="${WORKSPACE}/liquibase/liquibase.properties"

POSTGRES_JDBC_DRIVER_FILENAME="postgresql-42.1.4.jar"
POSTGRES_JDBC_DRIVER_URL="s3://${TF_VAR_bucket_name}/tools/${POSTGRES_JDBC_DRIVER_FILENAME}"

DOWNLOAD_RETRIES=5

# Download Liquibase binaries and PostgreSQL JDBC driver
echo "Downloading Liquibase binaries and PostgreSQL JDBC driver ..."
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

# Obtain RDS database endpoint
echo "Obtaining RDS database endpoint ..."
EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --db-instance-identifier ${TF_VAR_rds_identifier} \
    --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,DBInstanceStatus]' --output text`
MAX_RETRIES_TO_GET_DBINFO=20
RETRIES=0
while [[ -z `echo ${EXISTING_DB_INSTANCE_INFO} | grep "amazonaws"` ]] && [ ${RETRIES} -lt ${MAX_RETRIES_TO_GET_DBINFO} ]; do
    sleep 30
    EXISTING_DB_INSTANCE_INFO=`aws rds describe-db-instances --db-instance-identifier ${TF_VAR_rds_identifier} \
    --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,Endpoint.Port,DBInstanceStatus]' --output text`
    echo "Try: ${RETRIES}    DBinfo: ${EXISTING_DB_INSTANCE_INFO}"
    let "RETRIES++"
done
if [[ -z `echo ${EXISTING_DB_INSTANCE_INFO} | grep "amazonaws"` ]]; then
    echo "Failure - no RDS database with identifier ${TF_VAR_rds_identifier} available."
    exit 1
fi
DB_HOST=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $2}'`
DB_PORT=`echo ${EXISTING_DB_INSTANCE_INFO} | awk '{print $3}'`
echo "RDS endpoint: ${DB_HOST}:${DB_PORT}  Retries: ${RETRIES}"

# Update database using Liquibase
echo "Updating database using Liquibase ..."
aws rds wait db-instance-available --db-instance-identifier ${TF_VAR_rds_identifier}
sed "s/%LOGIN_HOST%/${LOGIN_HOST}/g" ${LIQUIBASE_PROPERTIES_TEMPLATE} |
    sed "s/%DB_HOST%/${DB_HOST}/g" |
    sed "s/%DB_PORT%/${DB_PORT}/g" |
    sed "s/%DB_NAME%/${DB_NAME}/g" |
    sed "s/%DB_USER%/${DB_USER}/g" |
    sed "s/%DB_PASS%/${DB_PASS}/g" > ${LIQUIBASE_PROPERTIES}

cd ${LIQUIBASE_BIN_DIR}
./liquibase --changeLogFile=../changelogs/changelog-main.xml --defaultsFile=../liquibase.properties update

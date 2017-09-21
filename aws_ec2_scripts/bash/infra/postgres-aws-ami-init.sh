#!/usr/bin/env bash
# set -e

function get_from_parameter_store {
    aws ssm get-parameters --names $1 --with-decryption --output text | awk '{print $4}'
}

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
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "SECRET_ACCESS_KEY"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "ACCESS_KEY_ID"`

export DB_HOST=`ifconfig | grep "inet addr" | grep -v -e "127.0.0.1" -e "10.0.2" | awk '{print $2}' | awk -F':' '{print $2}'`
export DB_PORT="5432"
export DB_NAME=`get_from_parameter_store "DB_NAME"`
export DB_USER=`get_from_parameter_store "DB_USER"`
export DB_PASS=`get_from_parameter_store "DB_PASS"`
export LOGIN_HOST="localhost"
ALLOWED_LAN=`echo ${DB_HOST}/24`

BUCKET_NAME="ansible-demo1"
OS_USERNAME=`whoami`
DEMO_DIR="demo1"
PROJECT_SRC_DIR="/home/${OS_USERNAME}/${DEMO_DIR}/DevOps028"

JDK_FILENAME="jdk-8u144-linux-x64.tar.gz"
JDK_URL="s3://${BUCKET_NAME}/${JDK_FILENAME}"
JDK_INSTALL_DIR="/usr/lib/jvm"

LIQUIBASE_PATH="${PROJECT_SRC_DIR}/liquibase"
LIQUIBASE_BIN_DIR="${LIQUIBASE_PATH}/bin"
LIQUIBASE_PROPERTIES_TEMPLATE="${LIQUIBASE_PATH}/liquibase.properties.template"
LIQUIBASE_PROPERTIES="${LIQUIBASE_PATH}/liquibase.properties"
LIQUIBASE_FILENAME="liquibase-3.5.3-bin.tar.gz"
LIQUIBASE_CHANGELOG_FILENAME="liquibase-changelog.tar.gz"
LIQUIBASE_URL="s3://${BUCKET_NAME}/${LIQUIBASE_FILENAME}"

POSTGRES_JDBC_DRIVER_FILENAME="postgresql-42.1.4.jar"
POSTGRES_JDBC_DRIVER_URL="s3://${BUCKET_NAME}/${POSTGRES_JDBC_DRIVER_FILENAME}"

DOWNLOAD_DIR="/home/${OS_USERNAME}/${DEMO_DIR}/download"
DOWNLOAD_RETRIES=5

# Install Python-Pip, Git, PostgreSQL, AWS cli
sudo yum -y update
sudo yum -y install epel-release
sudo yum -y install python python-pip postgresql-server mc
sudo `which pip` install --upgrade pip
sudo `which pip` install awscli

POSTGRES_CONF_UP=`sudo find /var/lib -name "pgsql*" | sort -u | head -n 1`
POSTGRES_CONF_DIR="${POSTGRES_CONF_UP}/data"
POSTGRES_SAMPLE_CONF_DIR=`sudo find /usr/share -name "pgsql*" | sort -u | head -n 1`

#export PGDATA=${POSTGRES_CONF_DIR}

# If postgres data folder is empty (ls -lh returns the only string "total 0") then initialize it
if [ `sudo ls -lh "${POSTGRES_CONF_UP}/data" | wc -l` -eq 1 ]; then
    sudo service postgresql initdb
fi

# Change Postgres config files
sudo cp "${POSTGRES_SAMPLE_CONF_DIR}/postgresql.conf.sample" "${POSTGRES_CONF_DIR}/postgresql.conf"
sudo chown postgres:postgres "${POSTGRES_CONF_DIR}/postgresql.conf"
sudo -u postgres sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '${DB_HOST}, 127.0.0.1'/g" "${POSTGRES_CONF_DIR}/postgresql.conf"
sudo -u postgres sed -i "s/port = 5432/port = ${DB_PORT}/g" "${POSTGRES_CONF_DIR}/postgresql.conf"
echo -e "data_directory = '${POSTGRES_CONF_DIR}'" | sudo -u postgres tee --append "${POSTGRES_CONF_DIR}/postgresql.conf"
echo -e "hba_file = '${POSTGRES_CONF_DIR}/pg_hba.conf'" | sudo -u postgres tee --append "${POSTGRES_CONF_DIR}/postgresql.conf"
# Add permission for DB_USER to connect to DB_NAME
echo -e "local \t all \t postgres \t\t \t\t \t\t peer \n host \t ${DB_NAME} \t ${DB_USER} \t\t ${ALLOWED_LAN} \t\t md5" | sudo -u postgres tee "${POSTGRES_CONF_DIR}/pg_hba.conf"

sudo service postgresql restart

# Create database and db_user
sudo -u postgres createdb ${DB_NAME}
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} to ${DB_USER};"

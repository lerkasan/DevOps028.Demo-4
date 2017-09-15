#!/usr/bin/env bash
set -e

export AWS_ACCESS_KEY_ID="---------------CHANGE_ME---------------"
export AWS_SECRET_ACCESS_KEY="-----------CHANGE_ME---------------"
export AWS_DEFAULT_REGION="us-west-2"

export DB_HOST=`ifconfig | grep "inet addr" | grep -v -e "127.0.0.1" -e "10.0.2" | awk '{print $2}' | awk -F':' '{print $2}'`
export DB_PORT="5432"
export DB_NAME="auradb"
export DB_USER="aura"
export DB_PASS="mysecretpassword"
export LOGIN_HOST="localhost"
ALLOWED_LAN=`echo ${DB_HOST}/24`

BUCKET_NAME="ansible-demo1"
OS_USERNAME=`whoami`
PROJECT_DIR="/home/${OS_USERNAME}/DevOps028"
WEB_APP_FILENAME="Samsara-1.3.5.RELEASE.jar"
REPO_URL="https://github.com/lerkasan/DevOps028.git"

JDK_FILENAME="jdk-8u144-linux-x64.tar.gz"
JDK_URL="s3://${BUCKET_NAME}/${JDK_FILENAME}"
JDK_DOWNLOAD_DIR="/usr/lib/jvm/downloaded"

MAVEN_FILENAME="apache-maven-3.5.0-bin.tar.gz"
MAVEN_URL="s3://${BUCKET_NAME}/${MAVEN_FILENAME}"
MAVEN_DOWNLOAD_DIR="/home/${OS_USERNAME}"

LIQUIBASE_PATH="${PROJECT_DIR}/liquibase"
LIQUIBASE_BIN_DIR="${LIQUIBASE_PATH}/bin"
LIQUIBASE_PROPERTIES_TEMPLATE="${LIQUIBASE_PATH}/liquibase.properties.template"
LIQUIBASE_PROPERTIES="${LIQUIBASE_PATH}/liquibase.properties"
LIQUIBASE_FILENAME="liquibase-3.5.3-bin.tar.gz"
LIQUIBASE_CHANGELOG_FILENAME="liquibase-changelog.tar.gz"
LIQUIBASE_URL="s3://${BUCKET_NAME}/${LIQUIBASE_FILENAME}"

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

# Install Python-Pip, Git, Maven, PostgreSQL, AWS cli
#sudo wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
#sudo sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo

sudo yum -y update
sudo yum -y install python-pip git mc #postgresql-server
sudo `which pip` install --upgrade pip
sudo `which pip` install awscli

# Change listen address binding to ethernet interface
# sudo su - postgres
# POSTGRES_CONF_DIR=`pwd`
# logout

POSTGRES_CONF_DIR=`sudo find /var/lib -name "pgsql*" | sort -u | tail -n 1`
POSTGRES_SAMPLE_CONF_DIR=`sudo find /usr/share -name "pgsql*" | sort -u | tail -n 1`

#POSTGRES_CONF_PATH="${POSTGRES_CONF_DIR}/postgresql.conf" # /var/lib/psql92 -конфиги, /usr/share/psql92
#POSTGRES_SAMPLE_CONF_DIR="`echo ${POSTGRES_CONF_DIR} | sed "s/var\/lib/usr\/share/g"`"
sudo cp "${POSTGRES_SAMPLE_CONF_DIR}/postgresql.conf.sample" "${POSTGRES_CONF_DIR}/postgresql.conf"
sudo chown postgres:postgres "${POSTGRES_CONF_DIR}/postgresql.conf"
sudo chmod -R 777 "${POSTGRES_CONF_DIR}"
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '${DB_HOST}, 127.0.0.1'/g" "${POSTGRES_CONF_DIR}/postgresql.conf"
sudo sed -i "s/port = 5432/port = ${DB_PORT}/g" "${POSTGRES_CONF_DIR}/postgresql.conf"

# Add permission for DB_USER to connect to DB_NAME from host machine by IP from vagrant private_network
sudo cp "${POSTGRES_SAMPLE_CONF_DIR}/pg_hba.conf.sample" "${POSTGRES_CONF_DIR}/pg_hba.conf"
sudo chown postgres:postgres "${POSTGRES_CONF_DIR}/pg_hba.conf"
sudo chmod -R 777 "${POSTGRES_CONF_DIR}"
sudo echo -e "host \t ${DB_NAME} \t ${DB_USER} \t\t ${ALLOWED_LAN} \t\t md5" >> "${POSTGRES_CONF_DIR}/pg_hba.conf"
sudo service postgresql initdb
sudo service postgresql restart

# Create database and db_user
sudo -u postgres createdb ${DB_NAME}
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} to ${DB_USER};"

# Clone sources from repo
mkdir -p ${PROJECT_DIR}
git clone ${REPO_URL}

# Download and install JDK
sudo mkdir -p ${JDK_DOWNLOAD_DIR}
if [ ! -e "${PROJECT_DIR}/${JDK_FILENAME}" ]; then
    download_from_s3 "${JDK_URL}" "${PROJECT_DIR}/${JDK_FILENAME}" ${DOWNLOAD_RETRIES}
fi
if [ -e "${PROJECT_DIR}/${JDK_FILENAME}" ]; then
    sudo tar -xzf "${PROJECT_DIR}/${JDK_FILENAME}" -C "${JDK_DOWNLOAD_DIR}"
fi

export JAVA_HOME=`find ${JDK_DOWNLOAD_DIR} -name java | grep -v openjdk | head -n 1 | rev | cut -c 10- | rev`
export PATH=$JAVA_HOME:$PATH

sudo alternatives --install /usr/bin/java java "${JAVA_HOME}/bin/java" 3
sudo alternatives --install /usr/bin/javac javac "${JAVA_HOME}/bin/javac" 3
sudo alternatives --set java "${JAVA_HOME}/bin/java"
sudo alternatives --set javac "${JAVA_HOME}/bin/javac"



# wget http://mirror.olnevhost.net/pub/apache/maven/binaries/apache-maven-3.2.1-bin.tar.gz
# sudo tar xzf apache-maven-3.2.1-bin.tar.gz -C /usr/local
# sudo ln -s /usr/local/apache-maven-3.2.1 maven

# Upload Liquibase changelog to AWS S3
if [ -e "${PROJECT_DIR}/${LIQUIBASE_CHANGELOG_FILENAME}" ]; then
    tar -czf "${PROJECT_DIR}/${LIQUIBASE_CHANGELOG_FILENAME}" ${LIQUIBASE_PATH}
fi
aws s3 cp "${PROJECT_DIR}/${LIQUIBASE_CHANGELOG_FILENAME}" "s3://${BUCKET_NAME}/${LIQUIBASE_CHANGELOG_FILENAME}"

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

# Build package with maven and upload it to aws s3
cd ${PROJECT_DIR}
mvn clean package
aws s3 cp ${WEB_APP_FILENAME} s3://${BUCKET_NAME}/${WEB_APP_FILENAME}

rm -r ${PROJECT_DIR}
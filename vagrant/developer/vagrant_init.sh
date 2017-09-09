#!/usr/bin/env bash

PROJECT_DIR="/home/ubuntu/demo1"
LIQUIBASE_BIN="liquibase/bin"

sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
sudo apt-get -qq -y install oracle-java8-set-default
sudo apt-get -y install maven postgresql mc

#Export global variables
source "/${PROJECT_DIR}/vagrant/developer/global_environment.sh"

#Change listen address binding to Vagrant ethernet interface to provide host machine connectivity to postgres through forwarded port
POSTGRES_CONF_PATH=`find /etc/postgresql -name "postgresql.conf"`
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '${DB_HOST}, 127.0.0.1'/g" ${POSTGRES_CONF_PATH}
sudo sed -i "s/port = 5432/port = ${DB_PORT}/g" ${POSTGRES_CONF_PATH}

#Add permission for DB_USER to connect to DB_NAME from host machine by IP from vagrant VM LAN
PG_HBA_PATH=`find /etc/postgresql -name "pg_hba.conf"`
sudo echo -e "host \t ${DB_NAME} \t ${DB_USER} \t\t ${ALLOWED_LAN} \t\t md5" >> ${PG_HBA_PATH}
service postgresql restart

#Create database and db_user
sudo -u postgres createdb ${DB_NAME}
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} to ${DB_USER};"

# by default wget makes 20 tries to download file if there is an error response from server (or use --tries=40 to increase retries amount).
# Exceptions are server responses CONNECTIONS_REFUSED and NOT_FOUND - in these cases wget will not retry download
mkdir ${PROJECT_DIR}/${LIQUIBASE_BIN}
wget https://github.com/liquibase/liquibase/releases/download/liquibase-parent-3.5.3/liquibase-3.5.3-bin.tar.gz -O "${PROJECT_DIR}/${LIQUIBASE_BIN}/liquibase-bin.tar.gz"
tar -xzf "${PROJECT_DIR}/${LIQUIBASE_BIN}/liquibase-bin.tar.gz" -C ${PROJECT_DIR}/${LIQUIBASE_BIN}
wget https://jdbc.postgresql.org/download/postgresql-42.1.4.jar -O "${PROJECT_DIR}/${LIQUIBASE_BIN}/lib/postgresql-42.1.4.jar"
cd ${PROJECT_DIR}/${LIQUIBASE_BIN} && cp ../liquibase.properties liquibase.properties
./liquibase update

echo "*********** INSTALLATION FINISHED. SYSTEM WILL REBOOT ************"
sudo reboot
#!/usr/bin/env bash
# set -e

export AWS_ACCESS_KEY_ID="---------------CHANGE_ME---------------"
export AWS_SECRET_ACCESS_KEY="-----------CHANGE_ME---------------"
export AWS_DEFAULT_REGION="us-west-2"

BUCKET_NAME="ansible-demo1"
OS_USERNAME=`whoami`
DEMO_DIR="demo1"

JDK_FILENAME="jdk-8u144-linux-x64.tar.gz"
JDK_URL="s3://${BUCKET_NAME}/${JDK_FILENAME}"
JDK_INSTALL_DIR="/usr/lib/jvm"

TOMCAT_VERSION="8.5.20"
TOMCAT_FILENAME="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TOMCAT_URL="s3://${BUCKET_NAME}/${TOMCAT_FILENAME}"
TOMCAT_INSTALL_DIR="/usr/local/tomcat"
TEMP_DIR="tmp"

DOWNLOAD_DIR="/home/${OS_USERNAME}/${DEMO_DIR}/download"
DOWNLOAD_RETRIES=5

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

# Install Python-Pip, Git, PostgreSQL, AWS cli
sudo yum -y update
sudo yum -y install epel-release
sudo yum -y install python python-pip git mc postgresql-server
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

sudo alternatives --install /usr/bin/java java "${JAVA_HOME}/bin/java" 2
sudo alternatives --install /usr/bin/javac javac "${JAVA_HOME}/bin/javac" 2
sudo alternatives --set java "${JAVA_HOME}/bin/java"
sudo alternatives --set javac "${JAVA_HOME}/bin/javac"

# Download Tomcat
sudo mkdir -p ${TOMCAT_INSTALL_DIR}
if [ ! -e "${DOWNLOAD_DIR}/${TOMCAT_FILENAME}" ]; then
    download_from_s3 "${TOMCAT_URL}" "${DOWNLOAD_DIR}/${TOMCAT_FILENAME}" ${DOWNLOAD_RETRIES}
fi
if [ -e "${DOWNLOAD_DIR}/${TOMCAT_FILENAME}" ]; then
    sudo tar -xzf "${DOWNLOAD_DIR}/${TOMCAT_FILENAME}" -C "${TOMCAT_INSTALL_DIR}"
fi

# Create user, group and change permissions
sudo groupadd tomcat
sudo useradd -M -s /bin/nologin -g tomcat -d ${TOMCAT_INSTALL_DIR} tomcat
#sudo chgrp -R tomcat ${TOMCAT_INSTALL_DIR}
sudo chown -R tomcat:tomcat ${TOMCAT_INSTALL_DIR}
sudo chmod 750 -R ${TOMCAT_INS/etc/systemd/system/tomcat.serviceTALL_DIR}
TOMCAT_STARTUP=`sudo find ${TOMCAT_INSTALL_DIR} -name "startup.sh"`

mkdir ${TEMP_DIR}
# Set root context for webapp in context.xml
echo "<?xml version='1.0' encoding='utf-8'?>" > ${TEMP_DIR}/context.xml
echo "<Context path="" docBase="Samsara-1.3.5.RELEASE.war" debug="0" reloadable="true"></Context>" >> ${TEMP_DIR}/context.xml
# Maybe it's better to use name Samsara.war and rename war-file after mvn clean package???
sudo cp "${TEMP_DIR}/context.xml" "${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}/conf/context.xml"
sudo chmod 750 "${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}/conf/context.xml"
sudo chown tomcat "${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}/conf/context.xml"

# Add user for curl deploy to tomcat-users.xml
echo "<?xml version='1.0' encoding='utf-8'?>" > ${TEMP_DIR}/tomcat-users.xml
echo '<tomcat-users xmlns="http://tomcat.apache.org/xml"' >> ${TEMP_DIR}/tomcat-users.xml
echo ' \t\t         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' >> ${TEMP_DIR}/tomcat-users.xml
echo ' \t\t         xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd" version="1.0">' >> ${TEMP_DIR}/tomcat-users.xml
echo ' \t <role rolename="admin"/>' >> ${TEMP_DIR}/tomcat-users.xml
echo ' \t <role rolename="admin-gui"/>' >> ${TEMP_DIR}/tomcat-users.xml
echo ' \t <role rolename="manager"/>' >> ${TEMP_DIR}/tomcat-users.xml
echo ' \t <role rolename="manager-gui"/>' >> ${TEMP_DIR}/tomcat-users.xml
echo ' \t <role rolename="manager-script"/>' >> ${TEMP_DIR}/tomcat-users.xml
echo ' \t <user username="tomadm" password="Rn7xU3kD2t" roles="admin,admin-gui,manager,manager-gui,manager-script" />' >> ${TEMP_DIR}/tomcat-users.xml
echo ' \t </tomcat-users>' >> ${TEMP_DIR}/tomcat-users.xml
sudo cp "${TEMP_DIR}/tomcat-users.xml" "${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}/conf/tomcat-users.xml"
sudo chmod 750 "${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}/conf/tomcat-users.xml"
sudo chown tomcat "${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}/conf/tomcat-users.xml"

# Ansible template config file is much better!!!
echo "# Systemd unit file for tomcat" > ${TEMP_DIR}/tomcat.service
echo "[Unit]" >> ${TEMP_DIR}/tomcat.service
echo "Description=Apache Tomcat Web Application Container" >> ${TEMP_DIR}/tomcat.service
echo "After=syslog.target network.target" >> ${TEMP_DIR}/tomcat.service
echo "" >> ${TEMP_DIR}/tomcat.service
echo "[Service]" >> ${TEMP_DIR}/tomcat.service
echo "Type=forking" >> ${TEMP_DIR}/tomcat.service
echo "" >> ${TEMP_DIR}/tomcat.service
echo "Environment=JAVA_HOME=${JAVA_HOME}" >> ${TEMP_DIR}/tomcat.service
echo "Environment=CATALINA_PID=${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}/temp/tomcat.pid" >> ${TEMP_DIR}/tomcat.service
echo "Environment=CATALINA_HOME=${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}" >> ${TEMP_DIR}/tomcat.service
echo "Environment=CATALINA_BASE=${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}" >> ${TEMP_DIR}/tomcat.service
echo "Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'" >> ${TEMP_DIR}/tomcat.service
echo "Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'" >> ${TEMP_DIR}/tomcat.service
echo "" >> ${TEMP_DIR}/tomcat.service
echo "ExecStart=${TOMCAT_STARTUP}" >> ${TEMP_DIR}/tomcat.service
echo "ExecStop=/bin/kill -15 $MAINPID" >> ${TEMP_DIR}/tomcat.service
echo "" >> ${TEMP_DIR}/tomcat.service
echo "User=tomcat" >> ${TEMP_DIR}/tomcat.service
echo "Group=tomcat" >> ${TEMP_DIR}/tomcat.service
echo "UMask=0007" >> ${TEMP_DIR}/tomcat.service
echo "RestartSec=10" >> ${TEMP_DIR}/tomcat.service
echo "Restart=always" >> ${TEMP_DIR}/tomcat.service
echo "" >> ${TEMP_DIR}/tomcat.service
echo "[Install]" >> ${TEMP_DIR}/tomcat.service
echo "WantedBy=multi-user.target" >> ${TEMP_DIR}/tomcat.service

sudo cp ${TEMP_DIR}/tomcat.service /etc/systemd/system/tomcat.service
sudo systemctl daemon-reload
sudo systemctl start tomcat

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

BUCKET_NAME="ansible-demo1"
OS_USERNAME=`whoami`
DEMO_DIR="demo1"

JDK_FILENAME="jdk-8u144-linux-x64.tar.gz"
JDK_URL="s3://${BUCKET_NAME}/${JDK_FILENAME}"
JDK_INSTALL_DIR="/usr/lib/jvm"

TOMCAT_VERSION="8.5.20"
TOMCAT_FILENAME="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TOMCAT_URL="s3://${BUCKET_NAME}/${TOMCAT_FILENAME}"
TOMCAT_INSTALL_DIR="/opt/tomcat"
TOMCAT_HOME="${TOMCAT_INSTALL_DIR}/apache-tomcat-${TOMCAT_VERSION}"
TOMCAT_USER=`get_from_parameter_store "TOMCAT_USER"`
TOMCAT_PASSWORD=`get_from_parameter_store "TOMCAT_PASSWORD"`
TEMP_DIR="/home/${OS_USERNAME}/tmp"

DOWNLOAD_DIR="/home/${OS_USERNAME}/${DEMO_DIR}/download"
DOWNLOAD_RETRIES=5

# Install Python-Pip, Git, PostgreSQL, AWS cli
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
TOMCAT_STARTUP=`sudo find ${TOMCAT_INSTALL_DIR} -name "startup.sh"`

mkdir ${TEMP_DIR}
# Make changes to tomcat_dir/webapp/manager/META-INF/context.xml to allow deploy through tomcat manager from different IP
sudo cp ${TOMCAT_HOME}/webapps/manager/META-INF/context.xml ${TEMP_DIR}/context.xml
sudo grep -v -e "Valve" -e "allow=" ${TEMP_DIR}/context.xml > ${TOMCAT_HOME}/webapps/manager/META-INF/context.xml

# Add user for curl deploy to tomcat-users.xml
echo "<?xml version='1.0' encoding='utf-8'?>" > ${TEMP_DIR}/tomcat-users.xml
echo '<tomcat-users xmlns="http://tomcat.apache.org/xml"' >> ${TEMP_DIR}/tomcat-users.xml
echo '          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' >> ${TEMP_DIR}/tomcat-users.xml
echo '          xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd" version="1.0">' >> ${TEMP_DIR}/tomcat-users.xml
echo '    <role rolename="admin"/>' >> ${TEMP_DIR}/tomcat-users.xml
echo '    <role rolename="admin-gui"/>' >> ${TEMP_DIR}/tomcat-users.xml
echo '    <role rolename="manager"/>' >> ${TEMP_DIR}/tomcat-users.xml
echo '    <role rolename="manager-gui"/>' >> ${TEMP_DIR}/tomcat-users.xml
echo '    <role rolename="manager-script"/>' >> ${TEMP_DIR}/tomcat-users.xml
echo "    <user username=\"${TOMCAT_USER}\" password=\"${TOMCAT_PASSWORD}\" roles=\"admin,admin-gui,manager,manager-gui,manager-script\" />" >> ${TEMP_DIR}/tomcat-users.xml
echo '</tomcat-users>' >> ${TEMP_DIR}/tomcat-users.xml
sudo cp "${TEMP_DIR}/tomcat-users.xml" "${TOMCAT_HOME}/conf/tomcat-users.xml"

#Add tomcat to start up
echo "# description: Tomcat Start Stop Restart Status" > ${TEMP_DIR}/tomcat
echo "# processname: tomcat" >> ${TEMP_DIR}/tomcat
echo "# chkconfig: 234 20 80" >> ${TEMP_DIR}/tomcat
echo "JAVA_HOME=${JAVA_HOME}" >> ${TEMP_DIR}/tomcat
echo "export JAVA_HOME" >> ${TEMP_DIR}/tomcat
echo "PATH=$JAVA_HOME/bin:$PATH" >> ${TEMP_DIR}/tomcat
echo "export PATH" >> ${TEMP_DIR}/tomcat
echo "CATALINA_HOME=${TOMCAT_HOME}" >> ${TEMP_DIR}/tomcat
echo 'case $1 in' >> ${TEMP_DIR}/tomcat
echo "start)" >> ${TEMP_DIR}/tomcat
echo 'sh ${CATALINA_HOME}/bin/startup.sh' >> ${TEMP_DIR}/tomcat
echo ";;" >> ${TEMP_DIR}/tomcat
echo "stop)" >> ${TEMP_DIR}/tomcat
echo 'sh ${CATALINA_HOME}/bin/shutdown.sh' >> ${TEMP_DIR}/tomcat
echo ";;" >> ${TEMP_DIR}/tomcat
echo "restart)" >> ${TEMP_DIR}/tomcat
echo 'sh ${CATALINA_HOME}/bin/shutdown.sh' >> ${TEMP_DIR}/tomcat
echo 'sh ${CATALINA_HOME}/bin/startup.sh' >> ${TEMP_DIR}/tomcat
echo ";;" >> ${TEMP_DIR}/tomcat
echo "status)" >> ${TEMP_DIR}/tomcat
echo "ps -ef | grep tomcat" >> ${TEMP_DIR}/tomcat
echo "esac" >> ${TEMP_DIR}/tomcat
echo "exit 0" >> ${TEMP_DIR}/tomcat

sudo chown -R tomcat:tomcat ${TOMCAT_INSTALL_DIR}
sudo chmod -R 750 ${TOMCAT_INSTALL_DIR}

sudo cp ${TEMP_DIR}/tomcat /etc/init.d/tomcat
sudo chmod 755 /etc/init.d/tomcat
sudo chkconfig --add tomcat
sudo chkconfig --level 234 tomcat on
sudo chkconfig --list tomcat

sudo rm -rf "${TOMCAT_HOME}/webapps/ROOT"
sudo service tomcat restart

export DB_NAME="auradbname"
export DB_HOST="somehost"
export DB_PORT=5432
#!/usr/bin/env bash

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
OS_USERNAME="ec2-user"
DEMO_DIR="demo2"

JDK_FILENAME="jdk-8u144-linux-x64.tar.gz"
JDK_URL="s3://${BUCKET_NAME}/tools/${JDK_FILENAME}"
JDK_INSTALL_DIR="/usr/lib/jvm"

DOWNLOAD_DIR="/home/${OS_USERNAME}/${DEMO_DIR}/download"
DOWNLOAD_RETRIES=5

# Install Python-Pip, AWS cli, Git
sudo yum -y update
sudo yum -y install epel-release git
sudo yum -y install python python-pip mc
sudo `which pip` install --upgrade pip
sudo `which pip` install awscli

# Add Jenkins master EC2 instance ssh public key to authorized_keys file at Jenkins slave node EC2 instance
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDX/CR9uiBypDzKE2MTWfUlF6ZUchBn+M0bsh6ayNh/x/4uaI6y38VX+g++sUoZjsyzsIx+tDAUKnOBkKnyEYRndlnb5n6YFHiCVmOtgG4DtGtYDmS1SgU3z9hW0zKFy6KA6ATMiTPZAdBMyYf1lu+oGaG/RtWybUuD/x0oJTDSR7gf8Q1lXbdycb4pQoDyv+CEWDOxOyv8GFULjB4y1VS44g+N2WNvZWx2iaI1011R3HV5rIG6YjEFrqSsCRKTDB5QssCozKRa8wSWuxGBAVoAmSnPBUijWjvdjt/C0hyVZUDONfhGaIMG4ldOE7hyJDuLTlgngJMhhcl4NmQ9J4bz ec2-user@ip-172-31-17-210" >> /home/ec2-user/.ssh/authorized_keys
echo "PubkeyAuthentication yes" | sudo tee --append /etc/ssh/sshd_config
sudo service sshd restart

#Download and install Terraform
wget https://releases.hashicorp.com/terraform/0.10.7/terraform_0.10.7_linux_amd64.zip
unzip terraform_0.10.7_linux_amd64.zip
export PATH="/home/ec2-user:${PATH}"

# Download and install JDK
#mkdir -p ${DOWNLOAD_DIR}
#sudo mkdir -p ${JDK_INSTALL_DIR}
#if [ ! -e "${DOWNLOAD_DIR}/${JDK_FILENAME}" ]; then
#    download_from_s3 "${JDK_URL}" "${DOWNLOAD_DIR}/${JDK_FILENAME}" ${DOWNLOAD_RETRIES}
#fi
#if [ -e "${DOWNLOAD_DIR}/${JDK_FILENAME}" ]; then
#    sudo tar -xzf "${DOWNLOAD_DIR}/${JDK_FILENAME}" -C "${JDK_INSTALL_DIR}"
#fi
#
#export JAVA_HOME=`find ${JDK_INSTALL_DIR} -name java | grep -v -e "openjdk" -e "jre" | head -n 1 | rev | cut -c 10- | rev`
#export PATH=${JAVA_HOME}/bin:${PATH}
#
#sudo alternatives --install /usr/bin/java java "${JAVA_HOME}/bin/java" 2
#sudo alternatives --install /usr/bin/javac javac "${JAVA_HOME}/bin/javac" 2
#sudo alternatives --set java "${JAVA_HOME}/bin/java"
#sudo alternatives --set javac "${JAVA_HOME}/bin/javac"


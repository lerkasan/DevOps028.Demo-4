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
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "jenkins_secret_access_key"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "jenkins_access_key_id"`

JENKINS_SSH_PUBLIC_KEY=`get_from_parameter_store "jenkins_master_ssh_public_key"`

# Install Python-Pip, AWS cli, Git
sudo yum -y update
sudo yum -y install epel-release git
sudo yum -y install python python-pip mc
sudo `which pip` install --upgrade pip
sudo `which pip` install awscli

# Add Jenkins master EC2 instance ssh public key to authorized_keys file at Jenkins slave node EC2 instance
echo "ssh-rsa ${JENKINS_SSH_PUBLIC_KEY} ec2-user@ip-172-31-17-210" >> /home/ec2-user/.ssh/authorized_keys
echo "PubkeyAuthentication yes" | sudo tee --append /etc/ssh/sshd_config
sudo service sshd restart

#Download and install Terraform
USER_HOME="/home/ec2-user"
wget https://releases.hashicorp.com/terraform/0.10.7/terraform_0.10.7_linux_amd64.zip -P ${USER_HOME}
cd ${USER_HOME} && unzip terraform_0.10.7_linux_amd64.zip
export PATH="${USER_HOME}:${PATH}"



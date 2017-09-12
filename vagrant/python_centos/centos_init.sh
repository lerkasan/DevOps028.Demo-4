#!/usr/bin/env bash

sudo yum -y update
sudo yum -y --enablerepo=extras install epel-release
sudo yum -y install python-pip
sudo pip install --upgrade pip
sudo pip install boto3

source ./centos_init.py

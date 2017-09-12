#!/usr/bin/env bash

sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y install python python-pip
pip install --upgrade pip
sudo pip install ansible

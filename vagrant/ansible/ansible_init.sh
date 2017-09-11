#!/usr/bin/env bash

sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y install python python-pip

# ansible-playbook playbooks/vagrant-playbook-init.yml --vault-password-file=conf/.vault_pass

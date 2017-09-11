#!/usr/bin/env bash
ansible-playbook playbooks/vagrant-playbook-startup.yml --vault-password-file=conf/.vault_pass

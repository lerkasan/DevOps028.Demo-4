#!/usr/bin/env bash
ansible-playbook playbooks/vagrant-playbook-startup.yml --vault-password-file=.vault_pass

# Demonstration of SpringBoot web application deployment to Kubernetes cluster at AWS using Jenkins

## Overview:
Script `DevOps028.Demo4/kubernetes/create_clusters.sh` will:
- create Kubernetes cluster at AWS and deploy to it:
  - preconfigured Jenkins with pipeline job to build and deploy web application
  - private Registry to store Docker images
- build all necessary Docker images for Jenkins and push it to private Registry
- create Kubernetes cluster at AWS for SpringBoot web application
- set alias DNS records at AWS for loadbalancers with:
  - Jenkins
  - Registry
  - Web application Samsara

After running this script you will be able to visit Jenkins site and run preconfigured job to build and deploy web application

## Prerequisites:
This tools should be installed before running deployment scripts:
- [kops](https://github.com/kubernetes/kops)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

Also you should have registered domain name, e.g. example.com, and SSL certificate (private key and certificate files) for domain registry.example.com

Registry also requires password authentification to be set. Please read this official [guideline](https://docs.docker.com/registry/deploying/#restricting-access) about restricting access to Registry 

You can change these variables and path to certificate files in bash script `DevOps028.Demo4/kubernetes/create_clusters.sh`

Please follow this official [guideline]((https://github.com/kubernetes/kops/blob/master/docs/aws.md)) about prerequisites for Kubernetes cluster creation at AWS.

## Deployment steps:
- Clone this git repository
- Export environment variables `AWS_DEFAULT_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- Run script `DevOps028.Demo4/kubernetes/create_clusters.sh`
- Open Jenkins website, e.g. [http://jenkins.lerkasan.de:8080](http://jenkins.lerkasan.de:8080)
- Run pipeline job called Demo4
- You also may explore Regitry with docker images [https://registry.lerkasan.de](https://registry.lerkasan.de)
- Wait for Jenkins to finish executing pipeline job
- Visit Samsara application website [http://samsara.lerkasan.de](http://samsara.lerkasan.de)

## About SpringBoot application:
Samsara application (authentication service)

## Web application stack
- Java 7
- Spring Boot
- Maven 3+
- Liquibase
- FreeMarker

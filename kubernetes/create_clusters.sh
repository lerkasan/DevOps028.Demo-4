#!/usr/bin/env bash

export AWS_DEFAULT_REGION="us-west-2"
# export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "jenkins_secret_access_key"`
# export AWS_ACCESS_KEY_ID=`get_from_parameter_store "jenkins_access_key_id"`

JENKINS_REGISTRY_CLUSTER="jenkins"
REGISTRY_URL="registry.lerkasan.de"
REGISTRY_DNS_RECORDS_FILE="registry_dns_records.json"
REGISTRY_LOGIN="lerkasan"
REGISTRY_PASSWORD="J*t47X8#RmF2"
JENKINS_SAMSARA_DNS_RECORDS_FILE="jenkins_samsara_dns_records.json"
HOSTED_ZONE_ID="ZZ3Z055672IF0"
PATH_TO_TLS="/etc/letsencrypt/live/registry.lerkasan.de"
PATH_TO_PASS="/home/lerkasan/auth"

function get_loadbalancer_name {
    kubectl describe svc $1 --namespace=$1 | grep Ingress | awk '{print $3}' | awk -F "-" '{print $1}'
}

function get_loadbalancer_dns {
    kubectl describe svc $1 --namespace=$1 | grep Ingress | awk '{print $3}'
}

function get_loadbalancer_zoneid {
    aws elb describe-load-balancers --load-balancer-name $1 --output text --query 'LoadBalancerDescriptions[*].{Name:CanonicalHostedZoneNameID}'
}

function create_cluster {
    NAME=$1
#    export CLUSTER_NAME="${NAME}-cluster.k8s.local"
    export CLUSTER_NAME="${NAME}.lerkasan.de"
    export KOPS_STATE_STORE="s3://${NAME}-cluster-state"
    echo $CLUSTER_NAME
    echo $KOPS_STATE_STORE

    kops create cluster --zones us-west-2a ${CLUSTER_NAME} --master-size=t2.medium --node-size=t2.medium --master-volume-size=20 --node-volume-size=20
#    kops create -f "./${NAME}-cluster.yaml"
    kops create secret --name ${CLUSTER_NAME} sshpublickey admin -i ~/.ssh/id_rsa.pub
    kops update cluster ${CLUSTER_NAME} --yes

    sleep 250
    CLUSTER_STATUS=`kops validate cluster ${CLUSTER_NAME} | grep "Your cluster" | grep "is ready"`
    MAX_RETRIES=20
    RETRIES=0
    while [[ -z `echo ${CLUSTER_STATUS}` ]] && [ ${RETRIES} -lt ${MAX_RETRIES} ]; do
        sleep 20
        CLUSTER_STATUS=`kops validate cluster ${CLUSTER_NAME} | grep "Your cluster" | grep "is ready"`
        echo "Try: ${RETRIES}     Cluster info: ${CLUSTER_STATUS}"
        let "RETRIES++"
    done
    if [[ -z `echo ${CLUSTER_STATUS}` ]]; then
        echo "Failure - no cluster for Jenkins is available."
        exit 1
    fi
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.7.1.yaml
    sleep 10
#    kubectl apply -f "./${NAME}-deployment.yaml"
    aws s3 cp ~/.kube/config ${KOPS_STATE_STORE}/kube-config
    cat ~/.kube/config
}


create_cluster ${JENKINS_REGISTRY_CLUSTER}
aws iam  attach-role-policy --role-name "nodes.${JENKINS_REGISTRY_CLUSTER}.lerkasan.de" --policy-arn arn:aws:iam::370535134506:policy/jenkins-nodes-kops
kubectl create namespace registry
kubectl create namespace jenkins

REGISTRY_EC2_INSTANCES=`aws ec2 describe-instances --filters "Name=tag:Name,Values=nodes.${JENKINS_REGISTRY_CLUSTER}.lerkasan.de" \
--query 'Reservations[*].Instances[*].[PublicDnsName]' --output text | grep -v -e terminated -e shutting-down`

for INSTANCE in ${REGISTRY_EC2_INSTANCES}; do
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa "${PATH_TO_TLS}/privkey.pem" "admin@${INSTANCE}:/home/admin/privkey.pem"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa "${PATH_TO_TLS}/fullchain.pem" "admin@${INSTANCE}:/home/admin/fullchain.pem"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa "${PATH_TO_TLS}/privkey.pem" "admin@${INSTANCE}:/home/admin/server.key"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa "${PATH_TO_TLS}/fullchain.pem" "admin@${INSTANCE}:/home/admin/server.crt"
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa "${PATH_TO_PASS}/htpasswd" "admin@${INSTANCE}:/home/admin/htpasswd"
done

kubectl apply -f "registry-deployment.yaml" --namespace=registry

REGISTRY_ELB_NAME=`get_loadbalancer_name registry`
REGISTRY_ELB_DNS=`get_loadbalancer_dns registry`
REGISTRY_ELB_ZONE_ID=`get_loadbalancer_zoneid ${REGISTRY_ELB_NAME}`

echo "Registry ELB name is ${REGISTRY_ELB_NAME}"
echo "Registry ELB DNS is ${REGISTRY_ELB_DNS}"
echo "Registry ELB DNS zoneId is ${REGISTRY_ELB_ZONE_ID}"

sed "s/%REGISTRY_ELB_DNS%/${REGISTRY_ELB_DNS}/g" "conf/template_${REGISTRY_DNS_RECORDS_FILE}" |
    sed "s/%REGISTRY_ELB_ZONE_ID%/${REGISTRY_ELB_ZONE_ID}/g" > ${REGISTRY_DNS_RECORDS_FILE}
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch "file://${REGISTRY_DNS_RECORDS_FILE}"

docker build -t jenkins-master:latest -f jenkins/Dockerfile.jenkins_master jenkins
docker tag jenkins-master:latest "${REGISTRY_URL}:5000/jenkins-master:latest"

# docker build -t jenkins-slave:latest -f jenkins/Dockerfile.jenkins_slave jenkins
# docker tag jenkins-slave:latest "${REGISTRY_URL}:5000/jenkins-slave:latest"

docker build -t jenkins-slave-mvn:latest -f jenkins/Dockerfile.jenkins_slave_mvn jenkins
docker tag jenkins-slave-mvn:latest "${REGISTRY_URL}:5000/jenkins-slave-mvn:latest"

docker build -t jenkins-slave-docker:latest -f jenkins/Dockerfile.jenkins_slave_docker jenkins
docker tag jenkins-slave-docker:latest "${REGISTRY_URL}:5000/jenkins-slave-docker:latest"

docker build -t jenkins-slave-kops:latest -f jenkins/Dockerfile.jenkins_slave_kops jenkins
docker tag jenkins-slave-kops:latest "${REGISTRY_URL}:5000/jenkins-slave-kops:latest"

sleep 600
MAX_RETRIES=50
RETRIES=0
while [[ -z `dig A ${REGISTRY_URL} | grep "NOERROR"` ]] && [ ${RETRIES} -lt ${MAX_RETRIES} ]; do
    let "RETRIES++"
    date
    echo "Digging ${REGISTRY_URL} from 8.8.8.8"
    dig A ${REGISTRY_URL} @8.8.8.8
    echo "Digging ${REGISTRY_URL} from localhost"
    dig A ${REGISTRY_URL}
    echo "Try: ${RETRIES}  ${REGISTRY_URL} domain is unavailable. Sleeping for 2 minutes."
    sleep 120
done

docker login "${REGISTRY_URL}:5000" -u ${REGISTRY_LOGIN} -p ${REGISTRY_PASSWORD}
docker push "${REGISTRY_URL}:5000/jenkins-master:latest"
# docker push "${REGISTRY_URL}:5000/jenkins-slave:latest"
docker push "${REGISTRY_URL}:5000/jenkins-slave-mvn:latest"
docker push "${REGISTRY_URL}:5000/jenkins-slave-docker:latest"
docker push "${REGISTRY_URL}:5000/jenkins-slave-kops:latest"

kubectl create secret docker-registry registry-pass --docker-server=${REGISTRY_URL}:5000 --docker-username=lerkasan --docker-password="J*t47X8#RmF2" --docker-email=lerkasan@gmail.com --namespace=jenkins
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "registry-pass"}]}' --namespace=jenkins
kubectl apply -f "jenkins-deployment.yaml" --namespace=jenkins

JENKINS_ELB_NAME=`get_loadbalancer_name jenkins`
JENKINS_ELB_DNS=`get_loadbalancer_dns jenkins`
JENKINS_ELB_ZONE_ID=`get_loadbalancer_zoneid ${JENKINS_ELB_NAME}`

echo "Jenkins ELB name is ${JENKINS_ELB_NAME}"
echo "Jenkins ELB DNS is ${JENKINS_ELB_DNS}"
echo "Jenkins ELB DNS zoneId is ${JENKINS_ELB_ZONE_ID}"


docker build -t jdk8:152 -f docker/Dockerfile.jdk docker
docker tag jdk8:152 "${REGISTRY_URL}:5000/jdk8:152"

docker build -t samsara-db:latest -f docker/Dockerfile.db docker
docker tag samsara-db:latest "${REGISTRY_URL}:5000/samsara-db:latest"

docker login "${REGISTRY_URL}:5000" -u ${REGISTRY_LOGIN} -p ${REGISTRY_PASSWORD}
docker push "${REGISTRY_URL}:5000/jdk8:152"
docker push "${REGISTRY_URL}:5000/samsara-db:latest"

create_cluster samsara
kubectl create namespace samsara
kubectl create secret generic dbuser-pass --from-literal=password=mysecretpassword --namespace=samsara
kubectl create secret docker-registry registry-pass --docker-server=${REGISTRY_URL}:5000 --docker-username=lerkasan --docker-password="J*t47X8#RmF2" --docker-email=lerkasan@gmail.com --namespace=samsara
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "registry-pass"}]}' --namespace=samsara
kubectl apply -f "database-deployment.yaml" --namespace=samsara
kubectl apply -f "samsara-deployment.yaml" --namespace=samsara
kubectl apply -f "samsara-pod.yaml" --namespace=samsara
kubectl apply -f "docker/datadog/dd_agent_kubernetes.yaml" --namespace=samsara

SAMSARA_ELB_NAME=`get_loadbalancer_name samsara`
SAMSARA_ELB_DNS=`get_loadbalancer_dns samsara`
SAMSARA_ELB_ZONE_ID=`get_loadbalancer_zoneid ${SAMSARA_ELB_NAME}`

echo "Samsara ELB name is ${SAMSARA_ELB_NAME}"
echo "Samsara ELB DNS is ${SAMSARA_ELB_DNS}"
echo "Samsara ELB DNS zoneId is ${SAMSARA_ELB_ZONE_ID}"

sed "s/%JENKINS_ELB_DNS%/${JENKINS_ELB_DNS}/g" "conf/template_${JENKINS_SAMSARA_DNS_RECORDS_FILE}" |
    sed "s/%JENKINS_ELB_ZONE_ID%/${JENKINS_ELB_ZONE_ID}/g" |
    sed "s/%SAMSARA_ELB_DNS%/${SAMSARA_ELB_DNS}/g" |
    sed "s/%SAMSARA_ELB_ZONE_ID%/${SAMSARA_ELB_ZONE_ID}/g" > ${JENKINS_SAMSARA_DNS_RECORDS_FILE}

aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch "file://${JENKINS_SAMSARA_DNS_RECORDS_FILE}"
# aws route53 get-change --id <place-change-id-here>

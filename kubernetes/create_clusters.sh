#!/usr/bin/env bash

export AWS_DEFAULT_REGION="us-west-2"
# export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "jenkins_secret_access_key"`
# export AWS_ACCESS_KEY_ID=`get_from_parameter_store "jenkins_access_key_id"`

JENKINS_REGISTRY_CLUSTER="jenkins-registry"
REGISTRY_URL="registry.lerkasan.de"
REGISTRY_DNS_RECORDS_FILE="registry_dns_records.json"
JENKINS_SAMSARA_DNS_RECORDS_FILE="jenkins_samsara_dns_records.json"
HOSTED_ZONE_ID="ZZ3Z055672IF0"
PATH_TO_TLS="/etc/letsencrypt/live/registry.lerkasan.de"


function get_loadbalancer_name {
    kubectl describe svc $1 | grep Ingress | awk '{print $3}' | awk -F "-" '{print $1}'
}

function get_loadbalancer_dns {
    kubectl describe svc $1 | grep Ingress | awk '{print $3}'
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
kubectl apply -f "registry-deployment.yaml" --namespace=registry

REGISTRY_ELB_NAME=`get_loadbalancer_name registry`
REGISTRY_ELB_DNS=`get_loadbalancer_dns registry`
REGISTRY_ELB_ZONE_ID=`get_loadbalancer_zoneid ${REGISTRY_ELB_NAME}`

REGISTRY_ELB_EC2_INSTANCES=`aws elb describe-load-balancers --load-balancer-name ${REGISTRY_ELB_NAME} \
    --output text --query 'LoadBalancerDescriptions[*].Instances[*].InstanceId'`

for INSTANCE_ID in ${REGISTRY_ELB_EC2_INSTANCES}; do
    EC2_HOST=`aws ec2 describe-instances --instance-ids ${INSTANCE_ID} \
        --query 'Reservations[*].Instances[*].[PublicDnsName]' --output text`
    sudo scp -q -i ~/.ssh/id_rsa "${PATH_TO_TLS}/privkey.pem" "admin@${EC2_HOST}:/home/admin/privkey.pem"
    sudo scp -q -i ~/.ssh/id_rsa "${PATH_TO_TLS}/fullchain.pem" "admin@${EC2_HOST}:/home/admin/fullchain.pem"
    sudo scp -q -i ~/.ssh/id_rsa "${PATH_TO_TLS}/privkey.pem" "admin@${EC2_HOST}:/home/admin/server.key"
    sudo scp -q -i ~/.ssh/id_rsa "${PATH_TO_TLS}/fullchain.pem" "admin@${EC2_HOST}:/home/admin/server.crt"
done

sed "s/%REGISTRY_ELB_DNS%/${REGISTRY_ELB_DNS}/g" "template_${REGISTRY_DNS_RECORDS_FILE}" |
    sed "s/%REGISTRY_ELB_ZONE_ID%/${REGISTRY_ELB_ZONE_ID}/g" > ${REGISTRY_DNS_RECORDS_FILE}
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch "file://${REGISTRY_DNS_RECORDS_FILE}"

docker build -t jenkins-slave:latest -f jenkins/Dockerfile.jenkins_slave jenkins
docker tag jenkins-slave:latest "${REGISTRY_URL}/jenkins-slave:latest"
docker push "${REGISTRY_URL}/jenkins-slave:latest"

docker build -t jenkins-master:latest -f jenkins/Dockerfile.jenkins_master jenkins
docker tag jenkins-master:latest "${REGISTRY_URL}/jenkins-master:latest"
docker push "${REGISTRY_URL}/jenkins-master:latest"

kubectl apply -f "jenkins-deployment.yaml" --namespace=jenkins


create_cluster samsara
kubectl create namespace samsara
kubectl create secret generic dbuser-pass --from-literal=password=mysecretpassword
kubectl apply -f "database-deployment.yaml" --namespace=samsara
kubectl apply -f "samsara-deployment.yaml" --namespace=samsara
kubectl apply -f "samsara-pod.yaml" --namespace=samsara

JENKINS_ELB_NAME=`get_loadbalancer_name jenkins`
JENKINS_ELB_DNS=`get_loadbalancer_dns jenkins`
JENKINS_ELB_ZONE_ID=`get_loadbalancer_zoneid ${JENKINS_ELB_NAME}`

SAMSARA_ELB_NAME=`get_loadbalancer_name samsara`
SAMSARA_ELB_DNS=`get_loadbalancer_dns samsara`
SAMSARA_ELB_ZONE_ID=`get_loadbalancer_zoneid ${SAMSARA_ELB_NAME}`

sed "s/%JENKINS_ELB_DNS%/${JENKINS_ELB_DNS}/g" "template_${JENKINS_SAMSARA_DNS_RECORDS_FILE}" |
    sed "s/%JENKINS_ELB_ZONE_ID%/${JENKINS_ELB_ZONE_ID}/g" |
    sed "s/%SAMSARA_ELB_DNS%/${SAMSARA_ELB_DNS}/g" |
    sed "s/%SAMSARA_ELB_ZONE_ID%/${SAMSARA_ELB_ZONE_ID}/g" > ${JENKINS_SAMSARA_DNS_RECORDS_FILE}

aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch "file://${JENKINS_SAMSARA_DNS_RECORDS_FILE}"
# aws route53 get-change --id <place-change-id-here>

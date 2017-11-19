#!/usr/bin/env bash

export AWS_DEFAULT_REGION="us-west-2"
# export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "jenkins_secret_access_key"`
# export AWS_ACCESS_KEY_ID=`get_from_parameter_store "jenkins_access_key_id"`

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

# create_cluster jenkins
#kubectl apply -f "registry-deployment.yaml"
REGISTRY_URL=registry.lerkasan.de

# REGISTRY_URL="`kubectl describe svc registry | grep Ingress | awk '{print $3}'`:5000"
## REGISTRY_URL=`kubectl describe svc registry | grep Ingress | awk '{print $3}'`
## sed -i "s/{{registry_url}}/${REGISTRY_URL}/g" *.yaml
## kubectl apply -f "registry-deployment.yaml"

#docker build -t jenkins-slave:latest -f jenkins/Dockerfile.jenkins_slave jenkins
#docker tag jenkins-slave:latest "${REGISTRY_URL}/jenkins-slave:latest"
#docker push "${REGISTRY_URL}/jenkins-slave:latest"
#
#docker build -t jenkins-master:latest -f jenkins/Dockerfile.jenkins_master jenkins
#docker tag jenkins-master:latest "${REGISTRY_URL}/jenkins-master:latest"
#docker push "${REGISTRY_URL}/jenkins-master:latest"
#
kubectl apply -f "jenkins-deployment.yaml"
aws iam  attach-role-policy --role-name nodes.jenkins-cluster.k8s.local --policy-arn arn:aws:iam::370535134506:policy/jenkins-nodes-kops
#
create_cluster samsara
kubectl create secret generic dbuser-pass --from-literal=password=mysecretpassword
kubectl apply -f "database-service.yaml"
kubectl apply -f "samsara-service.yaml"
kubectl apply -f "samsara-deployment.yaml"

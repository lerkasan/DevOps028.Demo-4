#!/usr/bin/env bash
# Requires one argument:
# string $1 - name of parameter in EC2 parameter store
function get_from_parameter_store {
    aws ssm get-parameter --name $1 --with-decryption --output text | awk '{print $4}'
}

export AWS_DEFAULT_REGION="us-west-2"
export AWS_SECRET_ACCESS_KEY=`get_from_parameter_store "jenkins_secret_access_key"`
export AWS_ACCESS_KEY_ID=`get_from_parameter_store "jenkins_access_key_id"`

export CLUSTER_NAME=`get_from_parameter_store "demo3_cluster_name"`
export KOPS_STATE_STORE=`get_from_parameter_store "demo3_kops_state_bucket"`

# kops create cluster --zones us-west-2a ${CLUSTER_NAME} -f kops-infra.yaml
echo "Creating cluster ..."
kops create cluster --zones us-west-2a ${CLUSTER_NAME} --master-size=t2.micro --node-size=t2.micro \
                                                       --master-volume-size=8 --node-volume-size=8
kops update cluster ${CLUSTER_NAME} --yes
sleep 180
echo "Adding dashboard ..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.7.1.yaml
echo "Deploying database ..."
sleep 20
kubectl apply -f kubernetes/database.yaml
echo "Deploying web application ..."
sleep 20
kubectl apply -f kubernetes/webapp.yaml
sleep 20
kubectl apply -f kubernetes/pod.yaml
sleep 20
kops rolling-update cluster ${CLUSTER_NAME} --yes
#kubectl run --image=370535134506.dkr.ecr.us-west-2.amazonaws.com/samsara:latest demo3-samsara-app --port=9000 --replicas=2
#kubectl expose deployment demo3-samsara-app --port=9000 --type=LoadBalancer
# kubectl proxy

aws s3 cp ~/.kube/config "${KOPS_STATE_STORE}/kube-config"

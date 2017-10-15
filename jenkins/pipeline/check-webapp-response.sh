#!/usr/bin/env bash
set -e

# Obtain public DNS address of load balancer
echo "Obtaining public DNS address of load balancer ..."
ELB_INFO=`aws elb describe-load-balancers --load-balancer-name ${TF_VAR_elb_name} --output text \
          --query 'LoadBalancerDescriptions[*].{Name:DNSName,Listeners:ListenerDescriptions[*].Listener.LoadBalancerPort}'`
export ELB_HOST=`echo ${ELB_INFO} | grep amazonaws | awk '{print $1}'`
export ELB_PORT=`echo ${ELB_INFO} | grep LISTENERS | awk '{print $3}'`
echo "ELB endpoint: ${ELB_HOST}:${ELB_PORT}"

# Wait for Spring Boot application to launch properly
echo "Waiting 60 seconds for Spring Boot application to launch properly before checking connectivity to webapp load balancer ..."
sleep 60

# Check connectivity to webapp loadbalancer
echo "Checking connectivity to webapp load balancer ..."
HTTP_CODE=`curl -s -o /dev/null -w "%{http_code}" "http://${ELB_HOST}:${ELB_PORT}${TF_VAR_health_check_path}"`
if [[ ${HTTP_CODE} > 399 ]]; then
	echo "HTTP_RESPONSE_CODE = ${HTTP_CODE}"
	exit 1
fi
echo "Webapp HTTP_RESPONSE_CODE = ${HTTP_CODE}"
echo "Webapp endpoint: ${ELB_HOST}:${ELB_PORT}"
#!/usr/bin/env bash

kubectl apply -f kubernetes/webapp.yaml
sleep 20
kubectl apply -f kubernetes/pod.yaml
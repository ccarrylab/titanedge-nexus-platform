#!/bin/bash

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add eks https://aws.github.io/eks-charts

helm install prometheus prometheus-community/kube-prometheus-stack

helm install grafana grafana/grafana

helm install aws-load-balancer-controller eks/aws-load-balancer-controller

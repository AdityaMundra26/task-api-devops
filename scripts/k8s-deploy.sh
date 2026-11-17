#!/usr/bin/env bash
# Build the image inside Minikube and deploy ConfigMap + Deployment + Service.
# Run from the project root:  ./scripts/k8s-deploy.sh
set -euo pipefail

IMAGE=task-api:1.0.0

echo ">> Building $IMAGE inside Minikube's Docker daemon"
minikube image build -t "$IMAGE" .

echo ">> Applying manifests"
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

echo ">> Waiting for rollout"
kubectl rollout status deployment/task-api --timeout=180s

kubectl get pods -l app=task-api -o wide
kubectl get svc task-api-service

URL=$(minikube service task-api-service --url)
echo ">> App URL: $URL"
curl -s "$URL/" ; echo
curl -s "$URL/tasks" ; echo

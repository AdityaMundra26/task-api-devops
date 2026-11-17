#!/usr/bin/env bash
# Rollback demo: push a broken version, watch it fail, then "kubectl rollout undo".
# Run: ./scripts/rollback-demo.sh
set -uo pipefail

echo ">> Current (working) version"
kubectl rollout history deployment/task-api
kubectl get pods -l app=task-api

echo ">> Deploying a BROKEN version (image tag that does not exist)"
kubectl annotate deployment/task-api kubernetes.io/change-cause="deploy 2.0.0-broken" --overwrite
kubectl set image deployment/task-api task-api=task-api:2.0.0-broken

echo ">> Rollout gets stuck - new pod cannot start (ImagePullBackOff / ErrImagePull)"
kubectl rollout status deployment/task-api --timeout=45s || echo "!! Rollout FAILED as expected"
kubectl get pods -l app=task-api
echo "   Note: the 3 old pods keep serving traffic because maxUnavailable=0 and the new pod never became Ready."

echo ">> Rolling back"
kubectl rollout undo deployment/task-api
kubectl rollout status deployment/task-api --timeout=120s
kubectl get pods -l app=task-api
kubectl rollout history deployment/task-api

URL=$(minikube service task-api-service --url)
echo ">> App responds again:"
curl -s "$URL/" ; echo

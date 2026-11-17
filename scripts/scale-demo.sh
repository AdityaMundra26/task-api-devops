#!/usr/bin/env bash
# Scaling demo: 3 -> 5 -> 2 replicas.  Run: ./scripts/scale-demo.sh
set -euo pipefail

echo ">> BEFORE scaling"
kubectl get pods -l app=task-api

echo ">> Scaling UP to 5 replicas"
kubectl scale deployment task-api --replicas=5
kubectl rollout status deployment/task-api --timeout=180s
kubectl get pods -l app=task-api

echo ">> Scaling DOWN to 2 replicas"
kubectl scale deployment task-api --replicas=2
sleep 10
kubectl get pods -l app=task-api

echo ">> Restoring 3 replicas"
kubectl scale deployment task-api --replicas=3
kubectl rollout status deployment/task-api --timeout=180s
kubectl get deployment task-api

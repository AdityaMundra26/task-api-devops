#!/usr/bin/env bash
# Creates the Git history the assignment asks for: main + feature branches + merges.
# Run ONCE from the project root, after setting your identity:
#   git config --global user.name  "Your Name"
#   git config --global user.email "you@example.com"
#   ./scripts/init-git-history.sh
set -euo pipefail

if [ -d .git ]; then
  echo "A .git folder already exists - aborting so nothing is overwritten."; exit 1
fi

git init -b main

# 1. main: the application itself
git add pom.xml .gitignore src/main
git commit -m "Add Task REST API (Spring Boot): GET /, GET /tasks, GET /tasks/{id}, POST /tasks"

# 2. feature/ci-pipeline: tests + Jenkins + GitHub Actions
git checkout -b feature/ci-pipeline
git add src/test
git commit -m "Add JUnit/MockMvc tests for task endpoints and health"
git add Jenkinsfile .github
git commit -m "Add Jenkins pipeline (test, build, versioned artifact) and GitHub Actions CI"
git checkout main
git merge --no-ff feature/ci-pipeline -m "Merge branch 'feature/ci-pipeline'"

# 3. feature/deployment: Docker + Ansible + Kubernetes
git checkout -b feature/deployment
git add Dockerfile .dockerignore
git commit -m "Add multi-stage Dockerfile"
git add ansible
git commit -m "Add Ansible playbook with task_api role, variable and handler"
git add k8s scripts
git commit -m "Add Kubernetes ConfigMap, Deployment (probes) and Service + demo scripts"
git checkout main
git merge --no-ff feature/deployment -m "Merge branch 'feature/deployment'"

# 4. docs
git add -A
git commit -m "Add README and repo link"

git log --oneline --graph --all
echo
echo "Done. Now create an EMPTY repo on GitHub and run:"
echo "  git remote add origin https://github.com/<you>/task-api-devops.git"
echo "  git push -u origin main feature/ci-pipeline feature/deployment"

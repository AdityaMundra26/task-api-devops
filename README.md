# Task API — CI/CD Pipeline & Kubernetes Deployment

DevOps assignment (25CIAEC59) — one application taken through the whole pipeline:

```
code ──► Git ──► Jenkins (test → build → versioned JAR) ──► Ansible (server setup)
                                                       └──► Docker ──► Kubernetes (3 → 5 replicas, rollback)
```

**Stack:** Java 17 · Spring Boot 3.3 · Maven · Git/GitHub · Jenkins · GitHub Actions · Ansible · Docker · Minikube/Kubernetes

---

## 1. The application

A small in-memory REST API (no database).

| Method | Path | What it does |
|---|---|---|
| GET | `/` | App info: version, environment, and **which pod** answered |
| GET | `/tasks` | List all tasks |
| GET | `/tasks/{id}` | One task (404 if missing) |
| POST | `/tasks` | Create a task — body `{"title": "..."}` → 201 |
| GET | `/actuator/health` | Health (also `/liveness` and `/readiness`, used by K8s probes) |

## 2. Project structure

```
task-api/
├── pom.xml                         Maven build (Spring Boot plugin → target/task-api.jar)
├── src/main/java/com/msrit/taskapi/  Application, controller, in-memory service
├── src/main/resources/application.properties
├── src/test/java/.../TaskControllerTest.java   5 JUnit tests (CI enhancement)
├── Jenkinsfile                     Checkout → Test → Build → (Docker) → archive versioned JAR
├── .github/workflows/ci.yml        GitHub Actions CI (bonus CI enhancement)
├── Dockerfile                      Multi-stage: Maven build stage → slim JRE runtime
├── ansible/
│   ├── ansible.cfg, inventory.ini, playbook.yml, requirements.yml
│   └── roles/task_api/             created with `ansible-galaxy init task_api`
│       ├── defaults/main.yml       variables (app_port, ...)
│       ├── handlers/main.yml       "restart task-api" handler
│       ├── tasks/main.yml          install Java, copy JAR, start service, health check
│       └── templates/              systemd unit, env file, service script
├── k8s/
│   ├── configmap.yaml              APP_PORT / APP_ENV / APP_VERSION
│   ├── deployment.yaml             3 replicas, liveness + readiness probes
│   └── service.yaml                NodePort 30080
├── scripts/                        k8s-deploy, scale-demo, rollback-demo, init-git-history
└── repo_link.txt
```

## 3. Setup checklist

Use **Ubuntu or WSL2** for Ansible (Ansible doesn't run on plain Windows).

```bash
git --version
java -version          # 17
mvn -v
docker --version
ansible --version      # pip install ansible   (or: sudo apt install ansible)
minikube version
kubectl version --client
```

---

# Component 1 — Git, Maven, Jenkins

### Step 1 — Run the app locally

```bash
mvn spring-boot:run
# second terminal:
curl http://localhost:8080/
curl http://localhost:8080/tasks
curl -X POST http://localhost:8080/tasks -H "Content-Type: application/json" -d '{"title":"Demo task"}'
curl http://localhost:8080/actuator/health
```

### Step 2 — Git (2+ branches and merges)

```bash
git config --global user.name  "Aditya Mundra"
git config --global user.email "<your GitHub email>"
./scripts/init-git-history.sh          # creates main + feature/ci-pipeline + feature/deployment with --no-ff merges
```

Create an **empty** repo `task-api-devops` on GitHub (no README), then:

```bash
git remote add origin https://github.com/AdityaMundra26/task-api-devops.git
git push -u origin main feature/ci-pipeline feature/deployment
```

Add the course coordinator as a collaborator: *Repo → Settings → Collaborators*.

📸 `git log --oneline --graph --all` (shows the merges) and GitHub's *Insights → Network* / branches page.

### Step 3 — Build locally

```bash
mvn clean package
ls -lh target/task-api.jar
java -jar target/task-api.jar
```

📸 `BUILD SUCCESS` with `Tests run: 5, Failures: 0`.

### Step 4 — Jenkins

Run Jenkins in Docker (keeps your laptop clean):

```bash
docker run -d --name jenkins -p 9090:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts-jdk17
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

1. Open http://localhost:9090 → paste the password → **Install suggested plugins** → create admin user.
2. **Manage Jenkins → Tools → Maven installations → Add Maven**: Name `maven3`, tick *Install automatically*. Save.
3. **New Item** → `task-api-pipeline` → **Pipeline**.
4. **Pipeline → Definition:** *Pipeline script from SCM* → SCM: **Git** → Repository URL: your GitHub URL → Branch: `*/main` → Script Path: `Jenkinsfile`. Save.
5. Click **Build Now** once (this registers the `pollSCM('* * * * *')` trigger from the Jenkinsfile).
6. **Prove CI:** make a small change and push it — Jenkins must start a build by itself within ~1 minute:
   ```bash
   sed -i 's/APP_VERSION:1.0.0/APP_VERSION:1.0.1/' src/main/resources/application.properties
   git commit -am "Bump version to 1.0.1" && git push
   ```

📸 Job config (SCM + trigger) · Console output ending in `SUCCESS` · Build page showing **"Started by an SCM change"** · Archived artifact `task-api-<build>-<sha>.jar` · **Test Result** page (5 passed).

### Step 5 — CI enhancement

**Chosen: Automated tests in CI** — the `Test` stage runs 5 JUnit/MockMvc tests *before* the `Build` stage; a failing test stops the pipeline, so a broken JAR is never archived.

Also implemented:
- **Build versioning** — artifact named `task-api-<BUILD_NUMBER>-<git-sha>.jar` (and Docker image tag if the agent has Docker).
- **GitHub Actions** — `.github/workflows/ci.yml` runs the same tests + build on every push (see the **Actions** tab).

📸 Stage View with green *Test* stage · JUnit trend · versioned artifact name · Actions run.

Try the failure case for your report: change an expected value in a test, push, and screenshot the red *Test* stage — then revert.

---

# Component 2 — Ansible + Docker + Kubernetes

### Step 1 — Ansible playbook

Target host = a Docker container acting as a server:

```bash
mvn clean package                                   # playbook copies target/task-api.jar
docker run -d --name app-host -p 8081:8080 ubuntu:22.04 sleep infinity
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini playbook.yml
curl http://localhost:8081/                          # "environment":"ansible"
```

What the playbook demonstrates:
- **Variable:** `app_port` (defaults/main.yml, overridden in playbook.yml) → becomes `APP_PORT`.
- **Handler:** `restart task-api` fires only when the JAR / env file / unit file changed. **Run the playbook a second time** → `changed=0` and no handler.
- **Role:** `roles/task_api` created with `ansible-galaxy init task_api`.
- Uses **systemd** on a VM/WSL host; inside a container (no systemd) it uses a `start-stop-daemon` service script.

Handler demo: `ansible-playbook -i inventory.ini playbook.yml -e app_version=1.0.1` → the env file changes → **RUNNING HANDLER [task_api : Restart task-api ...]** appears, and `curl http://localhost:8081/` shows `"version":"1.0.1"`.

📸 Full playbook output with `PLAY RECAP ... failed=0` · second run with `changed=0` · `curl` response.

### Step 2 — Docker

```bash
docker build -t task-api:1.0.0 .
docker run -d --name task-api -p 8080:8080 task-api:1.0.0
curl http://localhost:8080/tasks
docker images task-api            # compare size with the maven build image
docker rm -f task-api
```

### Step 3 — Kubernetes

```bash
minikube start
./scripts/k8s-deploy.sh           # builds image in Minikube, applies ConfigMap + Deployment + Service
```

Or manually:

```bash
minikube image build -t task-api:1.0.0 .
kubectl apply -f k8s/configmap.yaml -f k8s/deployment.yaml -f k8s/service.yaml
kubectl get pods
kubectl get svc
minikube service task-api-service --url
curl $(minikube service task-api-service --url)/
```

Call `/` several times — the `"pod"` field changes, proving the Service load-balances across replicas.

> On Docker Desktop/Windows, `minikube service --url` keeps a tunnel open; leave that terminal running and curl from another one.

### Step 4 — Scaling

```bash
./scripts/scale-demo.sh
# or by hand:
kubectl scale deployment task-api --replicas=5 && kubectl get pods
kubectl scale deployment task-api --replicas=2 && kubectl get pods
```

📸 `kubectl get pods` before (3), after scale-up (5), after scale-down (2).

### Step 5 — Deployment enhancement

**Chosen: Rollback demo** (with readiness/liveness probes making it safe):

```bash
./scripts/rollback-demo.sh
```

It deploys a broken version (non-existent image tag), shows the rollout stuck in `ErrImagePull`/`ImagePullBackOff`, runs `kubectl rollout undo deployment/task-api`, and shows the app responding again. Because `maxUnavailable: 0` and the readiness probe gates traffic, the old pods keep serving during the bad rollout — **zero downtime**.

Also implemented:
- **Liveness/readiness probes** on `/actuator/health/liveness` and `/readiness`.
- **ConfigMap** — `APP_PORT`, `APP_ENV`, `APP_VERSION` live in `k8s/configmap.yaml`, not in the code or Deployment.
  Demo: `kubectl edit configmap task-api-config` → change `APP_VERSION` → `kubectl rollout restart deployment/task-api` → `curl .../` shows the new value.
- **Multi-stage Dockerfile** — final image has only the JRE + JAR (no Maven, no source).
- **Health endpoint** — Spring Boot Actuator `/actuator/health`. Prometheus could scrape metrics too by adding `micrometer-registry-prometheus` and exposing `/actuator/prometheus` (request counts, latency, JVM memory/GC, etc.).

📸 Broken rollout pods · `rollout undo` output · `rollout history` · curl after recovery · `kubectl describe pod <pod>` showing the probes.

---

## Resume lines

**Task API — CI/CD Pipeline & Kubernetes Deployment** | github.com/AdityaMundra26/task-api-devops
*Java 17, Spring Boot, Maven, Git, Jenkins, GitHub Actions, Docker, Ansible, Kubernetes*

- Built a Spring Boot REST API for task management and automated its build pipeline with Jenkins, triggered on every Git push, with a JUnit test gate and artifacts versioned by build number + commit SHA.
- Configured server provisioning with an Ansible role (variables, change-triggered handlers); containerized with a multi-stage Dockerfile and deployed on Kubernetes with 3–5 replicas, ConfigMap-driven config, health probes, and a demonstrated zero-downtime rollback.

## Cleanup

```bash
kubectl delete -f k8s/
minikube stop
docker rm -f app-host jenkins
```

# Role: task_api

Installs a Java 17 runtime, copies `task-api.jar` to `/opt/task-api`, and runs it as a service.

- **systemd hosts** (Ubuntu VM, WSL with systemd): installs `/etc/systemd/system/task-api.service`.
- **Hosts without systemd** (a Docker container acting as a host): installs `/opt/task-api/task-api.sh`, a small `start-stop-daemon` service script.

## Variables (`defaults/main.yml`)

| Variable | Default | Meaning |
|---|---|---|
| `app_port` | `8080` | Port the API listens on (passed as `APP_PORT`) |
| `app_env` | `ansible` | Shown in `GET /` |
| `app_version` | `1.0.0` | Shown in `GET /` |
| `app_jar_src` | `../target/task-api.jar` | JAR on the control machine |

## Handler

`restart task-api` — runs only when the JAR, the env file or the systemd unit changed.
Run the playbook twice: the second run reports `changed=0` and the handler does not fire.

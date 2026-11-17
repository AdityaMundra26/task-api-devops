package com.msrit.taskapi;

import java.net.InetAddress;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TaskController {

    private final TaskService service;
    private final String appVersion;
    private final String appEnv;

    public TaskController(TaskService service,
                          @Value("${app.version}") String appVersion,
                          @Value("${app.env}") String appEnv) {
        this.service = service;
        this.appVersion = appVersion;
        this.appEnv = appEnv;
    }

    /** GET / — app info. "pod" shows which Kubernetes pod answered the request. */
    @GetMapping("/")
    public Map<String, Object> info() throws Exception {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("app", "task-api");
        body.put("version", appVersion);
        body.put("environment", appEnv);
        body.put("pod", InetAddress.getLocalHost().getHostName());
        return body;
    }

    /** GET /tasks — list all tasks. */
    @GetMapping("/tasks")
    public List<Task> list() {
        return service.findAll();
    }

    /** GET /tasks/{id} — one task, or 404. */
    @GetMapping("/tasks/{id}")
    public ResponseEntity<Task> get(@PathVariable long id) {
        return service.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /** POST /tasks — body {"title": "..."} creates a task. */
    @PostMapping("/tasks")
    public ResponseEntity<?> create(@RequestBody Map<String, String> request) {
        String title = request.get("title");
        if (title == null || title.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "title is required"));
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(service.add(title.trim()));
    }
}

package com.msrit.taskapi;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.stereotype.Service;

/** In-memory task store. A thread-safe list is enough for this assignment. */
@Service
public class TaskService {

    private final List<Task> tasks = new CopyOnWriteArrayList<>();
    private final AtomicLong nextId = new AtomicLong(1);

    public TaskService() {
        add("Set up Git repository");
        add("Configure Jenkins pipeline");
    }

    public List<Task> findAll() {
        return List.copyOf(tasks);
    }

    public Optional<Task> findById(long id) {
        return tasks.stream().filter(t -> t.id() == id).findFirst();
    }

    public Task add(String title) {
        Task task = new Task(nextId.getAndIncrement(), title, false);
        tasks.add(task);
        return task;
    }
}

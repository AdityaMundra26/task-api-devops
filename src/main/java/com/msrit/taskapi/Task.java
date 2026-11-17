package com.msrit.taskapi;

/** A single to-do item. Kept in memory only — no database. */
public record Task(long id, String title, boolean done) {
}

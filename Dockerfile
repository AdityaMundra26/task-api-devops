# ---------- Stage 1: build (has Maven + full JDK) ----------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src

# Download dependencies first so this layer is cached between builds
COPY pom.xml .
RUN mvn -B dependency:go-offline

COPY src ./src
RUN mvn -B package -DskipTests

# ---------- Stage 2: runtime (JRE only, no Maven, no source code) ----------
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Run as a non-root user
RUN addgroup -S app && adduser -S app -G app
COPY --from=build /src/target/task-api.jar app.jar
USER app

ENV APP_PORT=8080
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]

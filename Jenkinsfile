// Declarative Jenkins pipeline for task-api
// Jenkins job type: "Pipeline" -> Definition: "Pipeline script from SCM" -> Git -> this repo, branch */main
pipeline {
    agent any

    // Build Trigger: poll GitHub every minute; a push starts a build automatically.
    // (If you set up a GitHub webhook instead, you can replace this with githubPush().)
    triggers {
        pollSCM('* * * * *')
    }

    // Manage Jenkins -> Tools -> Maven installations -> Name: maven3 (tick "Install automatically").
    // Java comes from the Jenkins image itself (jenkins/jenkins:lts-jdk17).
    tools {
        maven 'maven3'
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        APP_NAME = 'task-api'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // CI enhancement: version every build with Jenkins build number + Git commit SHA
                    env.GIT_SHORT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.BUILD_VERSION = "${env.BUILD_NUMBER}-${env.GIT_SHORT_SHA}"
                    currentBuild.displayName = "#${env.BUILD_VERSION}"
                }
                echo "Building ${APP_NAME} version ${BUILD_VERSION}"
            }
        }

        // CI enhancement: unit tests run BEFORE the build; a failing test stops the pipeline.
        stage('Test') {
            steps {
                sh 'mvn -B clean test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Build') {
            steps {
                sh 'mvn -B package -DskipTests'
                // Rename the JAR so the artifact is traceable to the exact commit
                sh 'cp target/${APP_NAME}.jar target/${APP_NAME}-${BUILD_VERSION}.jar'
            }
        }

        stage('Docker Image') {
            // Runs only if Docker is available on the Jenkins agent; skipped otherwise.
            when {
                expression { sh(script: 'command -v docker', returnStatus: true) == 0 }
            }
            steps {
                sh 'docker build -t ${APP_NAME}:${BUILD_VERSION} -t ${APP_NAME}:latest .'
            }
        }
    }

    post {
        success {
            // Post-build action: archive the versioned JAR
            archiveArtifacts artifacts: "target/${APP_NAME}-${BUILD_VERSION}.jar", fingerprint: true
            echo "SUCCESS: ${APP_NAME}-${BUILD_VERSION}.jar archived"
        }
        failure {
            echo 'Build failed - check the Test stage report and console output.'
        }
    }
}

# Comprehensive Production CI/CD Pipeline

This project demonstrates a **production-grade CI/CD pipeline** with Jenkins, SonarQube, Docker, ArgoCD, Prometheus, Grafana, and Ansible. It automates **build → test → analysis → containerization → deployment → monitoring** for a **Java 17+ Maven application**, following DevOps and GitOps best practices.

Repository: [GitHub Link](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline)

---

## Table of Contents

* [1. Apache Reverse Proxy Setup](#1-apache-reverse-proxy-setup)
* [2. SSL Certificates](#2-ssl-certificates)
* [3. Jenkins SSH Build Node](#3-jenkins-ssh-build-node)
* [4. SonarQube Webhooks](#4-sonarqube-webhooks)
* [5. Java Application](#5-java-application)
* [6. CI Pipeline](#6-ci-pipeline)
* [7. CD Pipeline](#7-cd-pipeline)
* [8. Monitoring with Ansible](#8-monitoring-with-ansible)
* [Pipeline Diagrams](#pipeline-diagrams)

---

## 1. Apache Reverse Proxy Setup

I configured Apache HTTP Server as a reverse proxy for Jenkins and SonarQube, using domains registered from freedomain.one. This setup secures access to both services via their respective domains.

### Configuration Links

* Apache Config for Jenkins: [link-to-config](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/apache_configs/jenkins.conf)
* Apache Config for SonarQube: [link-to-config](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/apache_configs/sonarqube.conf)

### Example Screenshot

![Apache Reverse Proxy Screenshot](link-to-image)

---

## 2. SSL Certificates

I generated two SSL certificates for Apache using Certbot:

* ECDSA certificate
* RSA certificate

Both certificates are integrated into Apache VirtualHost configurations to secure connections.

---

## 3. Jenkins SSH Build Node

I created a dedicated SSH build node for Jenkins. I generated SSH keys and configured them for passwordless authentication, enabling Jenkins to run builds securely and efficiently on this node.

---

## 4. SonarQube Webhooks

I set up SonarQube webhooks to notify Jenkins of analysis results, enabling automated quality gate enforcement in pipelines.

---

## 5. Java Application

The pipeline builds and deploys a simple Java 17+ Maven application, which serves as the target workload. It is a clean Maven project, tested and packaged as part of the CI process.

---

# Jenkins Pipelines Explained

This project defines two Jenkins pipelines that deliver complete CI/CD functionality.

---

## 6. CI Pipeline

### Jenkinsfile: CI Pipeline

The CI pipeline is defined in `Jenkinsfile` and runs on a `jenkins-agent` node. It performs build, test, analysis, containerization, scanning, and deployment trigger steps.

### Stages

| Stage                    | Description                                            |
| ------------------------ | ------------------------------------------------------ |
| Initialize Workspace     | Cleans workspace with `cleanWs()`                      |
| Fetch Source Code        | Clones GitHub repository                               |
| Compile & Package        | `mvn clean package`                                    |
| Execute Unit Tests       | `mvn test`                                             |
| Run Static Code Analysis | SonarQube analysis with quality gate check             |
| Build Docker Image       | Builds and tags Docker image                           |
| Trivy Scan               | Scans Docker image for vulnerabilities                 |
| Push Docker Image        | Pushes Docker image with both unique and `latest` tags |
| Cleanup Artifacts        | Removes local Docker images                            |
| Trigger CD Pipeline      | Calls CD pipeline with new image tag                   |

### Notifications

Emails are sent on success and failure.

---

## 7. CD Pipeline

### Jenkinsfile: CD Pipeline

Triggered remotely by the CI pipeline via `gitops-token`. It updates deployment manifests, applies monitoring stack, and deploys or updates the monitoring stack using Ansible.

### Stages

| Stage                   | Description                                         |
| ----------------------- | --------------------------------------------------- |
| Cleanup Workspace       | Cleans workspace                                    |
| Checkout from SCM       | Clones GitHub repository                            |
| Update Deployment Tags  | Updates `argocd/deployment.yaml` with new image tag |
| Push Manifest to Git    | Commits and pushes updated manifest to GitHub       |
| Deploy Monitoring Stack | Executes Ansible playbook for monitoring stack      |

### Notifications

Emails are sent on success and failure.

---

## 8. Monitoring with Ansible

Ansible playbooks automate the deployment of the monitoring stack:

* cAdvisor & Jenkins target: Installed and added to Prometheus.
* Node Exporter: Installed and configured for Prometheus.
* Grafana: Installed and dashboards imported (`jenkins-dashboard.json`, `prometheus-overview.json`).

---

## Monitoring Tools

Prometheus collects metrics from Jenkins, cAdvisor, and Node Exporter.
Grafana visualizes metrics with preconfigured dashboards.

### CI/CD Workflow Diagram

```
[GitHub: main] → [CI Pipeline: Jenkinsfile]
    ↓
    - Initialize Workspace
    - Fetch Source Code
    - Compile & Package
    - Unit Tests
    - SonarQube Analysis → [Quality Gate]
    - Build Docker Image
    - Trivy Scan
    - Push Docker Image → [Docker Hub]
    - Cleanup
    - Trigger CD Pipeline
    ↓
[CD Pipeline: Jenkinsfile-cd]
    ↓
    - Cleanup Workspace
    - Checkout SCM
    - Update Deployment Tags → [GitHub: argocd/deployment.yaml]
    - Push to Git → [ArgoCD Sync]
    - Deploy Monitoring Stack → [Ansible: Prometheus, Grafana, etc.]
    ↓
[Deployed Application + Monitoring]
```

---

© [Mohamed Esmael](https://www.linkedin.com/in/mohamedesmael)

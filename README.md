
# Comprehensive Production CI/CD Pipeline

This project demonstrates a **production-grade CI/CD pipeline** with Jenkins, SonarQube, Docker, ArgoCD, Kubernetes, Prometheus, Grafana, and Ansible. It automates **build → test → analysis → containerization → deployment → monitoring** for a **Java 17+ Maven application**, following DevOps and GitOps best practices.

##  Project Links

*  **Jenkins Project Link**: [Comprehensive Production CI/CD Pipeline - Jenkins](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/tree/main)

You can also find the same project with **GitHub Actions** as the CI/CD tool:

*  **GitHub Actions Project Link**: [Comprehensive Production CI/CD Pipeline - GitHub Actions](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/tree/git-actions-pipeline)


You can also find the same project with **AWS CodePipeline** as the CI/CD tool:

* **AWS CodePipeline Project Link**: [Comprehensive Production CI/CD Pipeline - AWS CodePipeline](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/tree/codepipeline)

---

## Architecture Diagram

![Architecture Diagram](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/0.gif)

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


**Quickstart**  
```bash
git clone https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline.git
cd comprehensive-production-ci-cd-pipeline
```
### Kick off CI:
jenkins-job-run CI-pipeline

---

## 1. Apache Reverse Proxy Setup

I configured Apache HTTP Server as a reverse proxy for Jenkins and SonarQube, using domains registered from freedomain.one. This setup secures access to both services via their respective domains.

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/21.png)

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/06.png)


### Configuration Links

* Apache Config for Jenkins: [link-to-config](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/apache_configs/jenkins.conf)
* Apache Config for SonarQube: [link-to-config](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/apache_configs/sonarqube.conf)

---

## 2. SSL Certificates

I generated two SSL certificates for Apache using Certbot:

* ECDSA certificate
* RSA certificate

Both certificates are integrated into Apache VirtualHost configurations to secure connections.

---

## 3. Jenkins SSH Build Node

I created a dedicated SSH build node for Jenkins. I generated SSH keys and configured them for passwordless authentication, enabling Jenkins to run builds securely and efficiently on this node.


![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/26.png)


---

## 4. SonarQube Webhooks

I set up SonarQube webhooks to notify Jenkins of analysis results, enabling automated quality gate enforcement in pipelines.

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/13.png)


![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/07.png)


![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/18.png)



![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/34.png)


---

## 5. Java Application

The pipeline builds and deploys a simple Java 17+ Maven application, which serves as the target workload. It is a clean Maven project, tested and packaged as part of the CI process.

![Architecture Diagram](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/11.png)


![Architecture Diagram](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/14.png)


---

# Jenkins Pipelines Explained

This project defines two Jenkins pipelines that deliver complete CI/CD functionality.

---

## 6. CI Pipeline

### Jenkinsfile: CI Pipeline

The CI pipeline is defined in `Jenkinsfile` and runs on a `jenkins-agent` node. It performs build, test, analysis, containerization, scanning, and deployment trigger steps.

### Stages

![Architecture Diagram](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/39.png)

| Stage                         | Description                                                    |
| ----------------------------- | -------------------------------------------------------------- |
| Initialize Workspace          | Cleans workspace with `cleanWs()`                              |
| Fetch Source Code             | Clones GitHub repository                                       |
| Trivy File Scan               | Scans source tree for vuln. (skips `target/`, `.git`)          |
| Compile & Package Application | Builds the app with `mvn clean package`                        |
| Execute Unit Tests            | Runs unit tests via `mvn test`                                 |
| Run Static Code Analysis      | SonarQube analysis with `mvn sonar:sonar`                      |
| Enforce Quality Gate          | Waits/enforces SonarQube quality gate (simulated with `sleep`) |
| Build Docker Image            | Builds and tags Docker image (`${IMAGE_TAG}` and `latest`)     |
| Trivy Image Scan              | Scans the built Docker image for vulnerabilities               |
| Push Docker Image             | Pushes both `${IMAGE_TAG}` and `latest` tags to Docker Hub     |
| Cleanup Artifacts             | Removes local Docker images                                    |
| Trigger CD Pipeline           | Calls downstream CD pipeline with the new image tag            |

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/45.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/35.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/36.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/42.png)

### Notifications

Emails are sent on success and failure.

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/10.png)


![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/47.jpg)


---

## 7. CD Pipeline

### Jenkinsfile: CD Pipeline

Triggered remotely by the CI pipeline via `gitops-token`. It updates deployment manifests, applies monitoring stack, and deploys or updates the monitoring stack using Ansible.

### Stages

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/38.png)


| Stage                   | Description                                         |
| ----------------------- | --------------------------------------------------- |
| Cleanup Workspace       | Cleans workspace                                    |
| Checkout from SCM       | Clones GitHub repository                            |
| Update Deployment Tags  | Updates `argocd/deployment.yaml` with new image tag |
| Push Manifest to Git    | Commits and pushes updated manifest to GitHub       |
| Deploy Monitoring Stack | Executes Ansible playbook for monitoring stack      |

### Notifications

Emails are sent on success and failure.

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/49.jpg)

---

## 8. ArgoCD

Includes a `setup_k3s_argocd.sh` script to automate:

✅ K3s Kubernetes cluster installation
✅ ArgoCD installation with HTTPS ingress
✅ TLS certificates with cert-manager
✅ ArgoCD CLI installation and login

Run:

```bash
chmod +x setup_k3s_argocd.sh
./setup_k3s_argocd.sh
```
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/40.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/41.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/43.png)

Access ArgoCD at: [https://mohamedesmaelargocd.work.gd](https://mohamedesmaelargocd.work.gd)
[Script link](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/argocd/configs/setup_k3s_argocd.sh)

---


## 9. Monitoring with Ansible

Ansible playbooks automate the deployment of the monitoring stack:

* cAdvisor & Jenkins target: Installed and added to Prometheus.
* Node Exporter: Installed and configured for Prometheus.
* Grafana: Installed and dashboards imported (`jenkins-dashboard.json`, `prometheus-overview.json`).
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/16.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/31.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/22.png)


---



## 10. Monitoring Tools

Prometheus collects metrics from Jenkins, cAdvisor, and Node Exporter.
Grafana visualizes metrics with preconfigured dashboards.

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/19.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/29.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/09.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/23.png)



## CI/CD Workflow Diagram


![Workflow Diagram 1](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/01.png)

![Workflow Diagram 1](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/02.png)


## Additional Shots

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/25.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/12.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/24.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/28.png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/main/Screenshots/44.png)



---

© [Mohamed Esmael](https://www.linkedin.com/in/mohamedesmael)

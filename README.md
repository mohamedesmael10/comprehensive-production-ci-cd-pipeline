
# Comprehensive Production CI/CD Pipeline

This project demonstrates a **production-grade CI/CD pipeline** with **GitHub Actions**, **SonarCloud**, **Docker**, **ArgoCD**, **Kubernetes**, **Prometheus**, **Grafana**, and **Ansible**.
It automates **build → test → analysis → containerization → deployment → monitoring** for a **Java 17+ Maven application**, following **DevOps** and **GitOps** best practices.


##  Project Links

* **GitHub Actions Project Link**: [Comprehensive Production CI/CD Pipeline - GitHub Actions](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/tree/git-actions-pipeline)

You can also find the same project with **Jenkins** as the CI/CD tool:

* **Jenkins Project Link**: [Comprehensive Production CI/CD Pipeline - Jenkins](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/tree/main)


You can also find the same project with **AWS CodePipeline** as the CI/CD tool:

* **AWS CodePipeline Project Link**: [Comprehensive Production CI/CD Pipeline - AWS CodePipeline](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/tree/codepipeline)


---

## Architecture Diagram

![Architecture Diagram](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(0).gif)

## Table of Contents

* [1. CI Pipeline](#1-ci-pipeline)
* [2. CD Pipeline](#2-cd-pipeline)
* [3. ArgoCD Setup](#3-argocd-setup)
* [4. Monitoring with Ansible](#4-monitoring-with-ansible)
* [5. Monitoring Tools](#5-monitoring-tools)
* [CI/CD Workflow Diagram](#cicd-workflow-diagram)
* [Additional Screenshots](#additional-screenshots)

---

## Quickstart

```bash
git clone https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline.git
cd comprehensive-production-ci-cd-pipeline
```

Trigger the CI pipeline by running the workflow on GitHub Actions (`CI Pipeline`).

---

## 1. CI Pipeline

The **CI Pipeline** (`.github/workflows/ci-pipeline.yml`) performs:

✅ Build & Test

✅ Static Code Analysis via SonarCloud

✅ Vulnerability Scans (source & image) via Trivy

✅ Docker Image Build & Push

✅ GitHub Actions Notifications

✅ Trigger CD Pipeline

### Stages

| Stage                          | Description                                                     |
| ------------------------------ | --------------------------------------------------------------- |
| Checkout Repository            | Clones GitHub repository                                        |
| Trivy File Scan                | Scans source tree for vulnerabilities (skips `target/`, `.git`) |
| Build & Test                   | Maven `clean package`                                           |
| Copy Project Dependencies      | Copies Maven dependencies                                       |
| SonarCloud Scan & Quality Gate | Static analysis with SonarCloud                                 |
| Build Docker Image             | Builds and tags Docker image (`${IMAGE_TAG}` and `latest`)      |
| Trivy Image Scan               | Scans the built Docker image for vulnerabilities                |
| Push Docker Image              | Pushes both `${IMAGE_TAG}` and `latest` tags to Docker Hub      |
| Trigger CD Pipeline            | Calls downstream CD pipeline with the new image tag             |

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(8).png)

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(10).png)

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(4).png)

---

## 2. CD Pipeline

The **CD Pipeline** (`.github/workflows/cd-pipeline.yml`) performs:

✅ Deploy monitoring stack (Ansible)

✅ Update deployment manifest in GitHub

✅ Commit & push updated manifest

✅ Notifications

### Stages

| Stage                   | Description                                     |
| ----------------------- | ----------------------------------------------- |
| Checkout Repository     | Clones GitHub repository                        |
| Deploy Monitoring Stack | Runs `Ansible/deploy_monitoring.yaml`           |
| Update Deployment Tags  | Updates `argocd/deployment.yaml` with image tag |
| Push Manifest           | Commits and pushes manifest to GitHub           |
| Notifications           | Emails and logs status                          |

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(7).png)

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(9).png)

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(5).png)

---

## 3. ArgoCD & Monitoring with Ansible

The Ansible playbooks fully automate **both ArgoCD setup and monitoring stack deployment**.

✅ K3s Kubernetes cluster installation

✅ ArgoCD installation with HTTPS ingress

✅ TLS certificates with cert-manager

✅ ArgoCD CLI installation and login

✅ cAdvisor & Jenkins: monitored by Prometheus

✅ Node Exporter: installed and configured

✅ Grafana: installed and dashboards imported

Run the playbook:

```bash
ansible-playbook Ansible/deploy_monitoring.yaml
```

🔗 Access ArgoCD: [https://mohamedesmaelargocd.work.gd](https://mohamedesmaelargocd.work.gd)

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(15).png)

---


## CI/CD Workflow Diagram

![Workflow Diagram 1](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(11).png)
![Workflow Diagram 2](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(12).png)

---

## Additional Screenshots

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(6).png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(3).png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(2).png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(1).png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(14).png)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/git-actions-pipeline/Screenshots/(13).png)
---

## Credits

© [Mohamed Esmael](https://www.linkedin.com/in/mohamedesmael)

---


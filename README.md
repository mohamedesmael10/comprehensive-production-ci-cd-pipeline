```
# Comprehensive Production CI/CD Pipeline on AWS

This project demonstrates a **production-grade CI/CD pipeline** on AWS using **CodeCommit → CodeBuild → CodePipeline → ECR → EKS**, with automatic image promotion, deployments via Ansible, and notifications via SNS. It covers **build → test → analysis → containerization → deployment → monitoring** for a **Java 17+ Maven application**, following DevOps and GitOps best practices.

##  Project Links

* **AWS CodePipeline Project Link**: [Comprehensive Production CI/CD Pipeline - AWS CodePipeline](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/tree/codepipeline)

You can also find the same project with **GitHub Actions** as the CI/CD tool:

*  **GitHub Actions Project Link**: [Comprehensive Production CI/CD Pipeline - GitHub Actions](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/tree/git-actions-pipeline)


You can also find the same project with **Jenkins** as the CI/CD tool:
*  **Jenkins Project Link**: [Comprehensive Production CI/CD Pipeline - Jenkins](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/tree/main)


---
## Architecture Diagram

![Architecture Diagram](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(1).gif)



##  Table of Contents

| Section                        | Description                                                    |
| ------------------------------ | -------------------------------------------------------------- |
| [Quickstart](#quickstart)      | How to clone, bootstrap infra, and kick off pipelines          |
| [AWS Resources](#aws-resources)| Overview of S3, IAM, ECR, CodeBuild, CodePipeline, EKS, etc.   |
| [Pipeline Stages](#pipeline-stages) | Detailed CI/CD build steps                            |
| [Deployment Playbook](#deployment-playbook) | What `deploy_monitoring.yaml` does                 |
| [Auto-Rollout](#automatic-rollout)      | EventBridge→Lambda patch logic                     |
| [Monitoring Stack](#monitoring-stack)   | Prometheus, Grafana, Elasticsearch/Kibana, Cert-Manager |
| [DNS Configuration](#dns-configuration) | Your freedomain.one records                          |
| [Environment Variables](#environment-variables) | Variables used by CodeBuild/CD                   |
| [Adding New Services](#adding-new-services) | How to extend the pipeline                         |
| [Troubleshooting](#troubleshooting)     | Common gotchas & fixes                              |

---

## 

This repository demonstrates:

- **Infrastructure as Code** with Terraform  
- **CI/CD orchestration** via AWS CodePipeline & CodeBuild  
- **Container registry** using Amazon ECR  
- **Automated deployments** to Amazon EKS (Kubernetes)  
- **Auto‐rollout** on image push with EventBridge & Lambda  
- **Monitoring & alerting** with Prometheus, Grafana, and Cert-Manager for TLS  
- **Configuration** via Ansible & Helm  

It targets a **Java 17+ Maven** microservice but can be adapted to any containerized app.

---

##  Prerequisites

- AWS account with IAM permissions for CodeCommit, CodeBuild, CodePipeline, ECR, SNS, Lambda, EKS  
- EKS cluster with IAM OIDC enabled and a service account bound to an IAM role in `aws-auth`  
- (Optional) Route53 or DNS for your app domains  

---


##  Repository Structure

```

.
├── Ansible/                    # Playbooks & configuration for deploying to EKS
│   ├── ansible.cfg             # Ansible settings
│   └── deploy\_monitoring.yaml  # Installs app, monitoring stack, TLS, etc.
├── Configurations/             # Raw YAMLs & scripts for infra components
│   ├── ECR\_Image\_Push\_To\_K8s\_Deploy\_Config/
│   │   ├── EventBridge\_Rules/
│   │   │   └── Amazon\_EventBridge.json   # EventBridge rule for ECR PUSH
│   │   └── lambda/
│   │       ├── lambda\_function.py        # Auto‐rollout Lambda code
│   │       ├── lambda-sa.yaml            # ServiceAccount for Lambda
│   │       └── layer.zip                 #  Lambda dependencies
│   └── K8S/
│       ├── cert-manager.yaml            # cert-manager install manifest
│       ├── ingress-nginx.yaml           # NGINX Ingress Controller manifest
│       └── Service.yaml                 #  Service definitions
├── Dockerfile                      # Builds your Java microservice image
├── META-INF/
│   └── MANIFEST.MF                # JAR metadata
├── mvnw, mvnw\.cmd                 # Maven wrapper scripts
├── pom.xml                        # Maven project descriptor
├── prometheus/                    # Custom Prometheus & Grafana dashboards 
│   ├── jenkins-dashboard.json
│   ├── prometheus-overview\.json
│
├── src/                           # Your Java application code & tests
│   ├── main/java/com/demo/…       # Spring Boot app
│   └── test/java/com/demo/…       # Unit tests
├── target/                        # Maven build output (JAR, classes, reports)
└── Terraform/                     # IaC for AWS infra, pipelines, EKS, etc.
├── buildspec-ci.yml          # CI buildspec (compile, scan, dockerize)
├── buildspec-cd.yml          # CD buildspec (runs Ansible deploy)
├── main.tf                   # Terraform resources
├── variables.tf              # Terraform inputs
├── outputs.tf                # Terraform outputs
├── terraform.tfvars          # Your variable values
└── patch\_aws\_auth.sh         # Script to patch aws-auth in EKS

```
```

---

##  Quickstart

1. **Clone** this repo:  
   ```bash
   git clone https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline.git
   cd comprehensive-production-ci-cd-pipeline
````

2. **Provision AWS Infra** via Terraform:

   ```bash
   cd terraform
   terraform init
   terraform apply -auto-approve
   ```
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(2).jpg)

3. **Push** your application code to GitHub → CodePipeline triggers automatically.

4. **Monitor** builds in the AWS Console and dashboards in Grafana.

---

##  AWS Resources

| Resource                       | Description                                                                   |
| ------------------------------ | ----------------------------------------------------------------------------- |
| **S3 bucket**                  | Stores CodePipeline artifacts                                                 |
| **IAM roles & policies**       | Permissions for CodeBuild, CodePipeline, Lambda, and EKS worker nodes         |
| **ECR repository**             | Hosts Docker images                                                           |
| **CodeBuild projects**         | *ci-build* (build/test/scan/dockerize), *cd-deploy* (deploy via Ansible/Helm) |
| **CodePipeline**               | Orchestrates Source → CI → CD                                                 |
| **EventBridge rule**           | Listens for ECR image pushes                                                  |
| **Lambda function**            | Patches Kubernetes Deployments with new image tags                            |
| **SNS topic**                  | Receives build/deploy notifications                                           |
| **EKS cluster**                | Runs your app & monitoring stack                                              |
| **Cert-Manager** & **Ingress** | Provides Let’s Encrypt TLS for services                                       |

---

##  CI Pipeline (`buildspec-ci.yml`)

| Stage                         | Description                                                    |
| ----------------------------- | -------------------------------------------------------------- |
| **Initialize Workspace**      | Cleans workspace (`cleanWs()`)                                 |
| **Fetch Source Code**         | Clones your GitHub repo via CodePipeline                       |
| **Trivy File Scan**           | Scans source tree for vulnerabilities (`.git`, `target/` skipped) |
| **Compile & Package**         | `mvn clean package` (compiles, packages JAR)                   |
| **Execute Unit Tests**        | `mvn test`                                                    |
| **Static Code Analysis**      | SonarCloud (`mvn sonar:sonar`)                                 |
| **Quality Gate**              | Waits/enforces SonarCloud quality gate (with a `sleep` hack)   |
| **Build Docker Image**        | `docker build -t $ECR_REPO_URI:$IMAGE_TAG .`                   |
| **Tag Latest**                | `docker tag $ECR_REPO_URI:$IMAGE_TAG $ECR_REPO_URI:latest`     |
| **Trivy Image Scan**          | `trivy image --exit-code 1 $ECR_REPO_URI:$IMAGE_TAG`           |
| **Push Docker Image**         | `docker push` both `$IMAGE_TAG` and `latest` tags              |
| **Cleanup Local Images**      | Removes images from local Docker cache                         |
| **Publish SNS Notification**  | Alerts subscribers of success/failure                          |
| **Trigger CD Pipeline**       | Starts downstream CD via CodePipeline with new `IMAGE_TAG`     |

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(3).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(4).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(12).png)
---

##  CD Pipeline (`buildspec-cd.yml`)


| Stage                         | Description                                                    |
| ----------------------------- | -------------------------------------------------------------- |
| **Input Artifacts**           | Receives `build_output` from CI stage                          |
| **Configure kubeconfig**      | `aws eks update-kubeconfig` for your EKS cluster               |
| **Run Ansible Playbook**      | Executes `deploy_monitoring.yaml`                              |
| **Deploy Application**        | Creates/updates Kubernetes Deployment & Service for your app   |
| **Install Monitoring**        | Helm charts: Prometheus, Grafana, Elasticsearch & Kibana       |
| **Install cert-manager**      | Deploys Cert-Manager and `ClusterIssuer` for Let's Encrypt     |
| **Create Ingresses**          | TLS-terminating Ingress for App, Prometheus, Grafana, ES      |
| **Clean Kibana Hooks**        | Removes stale Helm hook resources before upgrading Kibana      |
| **Install Fluent Bit**        | Helm chart to ship logs to CloudWatch                          |
| **Post-Deploy SNS Alert**     | Optional: notify via SNS on successful CD                      |

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(5).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(6).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(11).png)
---

##  Deployment Playbook

**`ansible/deploy_monitoring.yaml`** provisions and configures all runtime components on EKS:

1. **Configure kubectl** against your EKS cluster
2. **Add Helm repos** and install the Kubernetes Python client
3. **Deploy your application** (Deployment + Service)
4. **Install Prometheus** via Helm (with persistent volumes)
5. **Install Grafana** via Helm (with persistence & admin password)
6. **Install Elasticsearch & Kibana** via Helm (secure cluster + HTTPs Ingress)
7. **Install cert-manager** & create a `ClusterIssuer` for Let’s Encrypt
8. **Create Ingresses** (Elasticsearch, Grafana, Prometheus, My App) with HTTP-01 solver and TLS
9. **Clean stale Kibana hooks** before upgrade
10. **Install Fluent Bit** via Helm for CloudWatch logs shipping

You can inspect that playbook under `ansible/deploy_monitoring.yaml` for full details.

---


##  Automatic Rollout

* **EventBridge** watches for ECR `PUSH` events on your repo.
* Triggers **Lambda**, which:

  1. Retrieves the new `imageTag` from the event.
  2. Generates a kubeconfig for EKS.
  3. Patches your Deployment via Kubernetes Python client:

     ```python
     patch = {
       "spec": {
         "template": {
           "metadata": {
             "annotations": {
               "kubectl.kubernetes.io/restartedAt": datetime.utcnow().isoformat()
             }
           },
           "spec": {
             "containers": [
               {"name": "<container_name>", "image": f"{repo_uri}:{imageTag}"}
             ]
           }
         }
       }
     }
     ```
  4. Forces a rolling update.
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(20).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(21).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(22).jpg)

---

##  Monitoring Stack

* **Prometheus**: metrics collection (Helm chart)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(12).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(13).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(14).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(15).jpg)
* **Grafana**: dashboard (Helm chart)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(16).jpg)
* **Elasticsearch & Kibana**: logs & visualization (Helm charts)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(10).jpg)
* **Cert-Manager**: Let’s Encrypt TLS for all Ingresses
* **Fluent Bit**: ship logs to CloudWatch
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(17).jpg)

---

##  DNS Configuration

Using [freedomain.one](https://freedomain.one/) you should add **CNAME** records for *each* service:

| Host                                   | Target                                                                           |
| -------------------------------------- | -------------------------------------------------------------------------------- |
| `elasticsearch.mohamedesmael.work.gd.` | `ac3c5e8cad90b4a8f84343d345ee113e-a637c3921e3c67d6.elb.us-east-1.amazonaws.com.` |
| `grafana.mohamedesmael.work.gd.`       | `ac3c5e8cad90b4a8f84343d345ee113e-a637c3921e3c67d6.elb.us-east-1.amazonaws.com.` |
| `kibana.mohamedesmael.work.gd.`        | `ac3c5e8cad90b4a8f84343d345ee113e-a637c3921e3c67d6.elb.us-east-1.amazonaws.com.` |
| `myapp.mohamedesmael.work.gd.`         | `ac3c5e8cad90b4a8f84343d345ee113e-a637c3921e3c67d6.elb.us-east-1.amazonaws.com.` |
| `prometheus.mohamedesmael.work.gd.`    | `ac3c5e8cad90b4a8f84343d345ee113e-a637c3921e3c67d6.elb.us-east-1.amazonaws.com.` |

Make sure those records are live before issuing certificates.

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(7).jpg)
---


##  Environment Variables

## 🔐 Environment Variables

Environment variables used throughout **CodeBuild**, **CodePipeline**, and **Lambda** are grouped below.  
** Sensitive values should be stored in [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html), NOT in Terraform.**

---

### 📦 General Pipeline Variables

| Variable             | Purpose                                                     |
| -------------------- | ----------------------------------------------------------- |
| `AWS_REGION`         | AWS region (e.g. `us-east-1`)                               |
| `AWS_ACCOUNT_ID`     | Your AWS account ID                                         |
| `ECR_REPO_NAME`      | ECR repository name                                         |
| `ECR_REPO_URI`       | `${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/...` |
| `IMAGE_TAG`          | CI build number, passed to CD                               |
| `EKS_CLUSTER_NAME`   | EKS cluster identifier                                      |
| `EKS_NAMESPACE`      | Kubernetes namespace for your application & monitoring      |
| `EKS_SERVICE_NAME`   | Kubernetes Deployment name                                  |
| `CODECONNECTION_ARN` | ARN for CodeStar GitHub connection                          |

---

###  Secrets (Store in AWS Secrets Manager)

| Secret Name         | Description                                 |
| ------------------- | ------------------------------------------- |
| `DOCKERHUB_USER`    | DockerHub username (used for docker login)  |
| `DOCKERHUB_PASS`    | DockerHub password (store as a secret)      |
| `SONAR_TOKEN`       | Token for SonarCloud authentication         |
| `EKS_KUBECONFIG`    | Kubeconfig (optional, for Lambda use)       |
| `TRIVY_GITHUB_TOKEN`| Optional token to avoid GitHub API limits   |
| `ELASTIC_PASSWORD`  | Auto-generated password from Elasticsearch  |

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(7).png)
---

##  Adding New Services

1. **Terraform**:

   * Extend `terraform/main.tf` to add new CodeBuild/CodePipeline stages
   * Add IAM permissions if needed

2. **Application Code**:

   * Commit changes → pipelines trigger automatically

3. **Ansible/Helm**:

   * Modify `ansible/deploy_monitoring.yaml` to install new Helm charts or apply Kubernetes manifests

---

##  Troubleshooting

* **Ingress 502 errors**:

  * Ensure `nginx.ingress.kubernetes.io/backend-protocol` matches your Service’s protocol (`HTTP` vs `HTTPS`).
  * Verify Service selector labels match your Pods.
  * Check Pod readiness and health probes.

* **Cert-Manager Challenges stuck**:

  * Confirm Ingress has ACME‐challenge path and correct annotations.
  * Verify DNS A/CNAME records point your domain to the Ingress controller’s LoadBalancer address.

* **Permissions errors**:

  * Inspect IAM role policies attached to CodeBuild and Lambda.
  * Add `eks:DescribeClusterVersions` for OIDC association, EKS access, etc.

---

## Additional Shots

![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(18).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(19).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(23).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(24).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(25).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(8).jpg)
![Screenshots](https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline/blob/codepipeline/Screenshots/(8).png)

---
© 2025 Mohamed Esmael · [LinkedIn](https://www.linkedin.com/in/mohamedesmael/) · [GitHub](https://github.com/mohamedesmael10/)

```
```

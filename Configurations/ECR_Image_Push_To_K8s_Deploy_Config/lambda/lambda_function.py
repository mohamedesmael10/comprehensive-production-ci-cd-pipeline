import json
import os
from kubernetes import client, config

def lambda_handler(event, context):
    print("Event received:", json.dumps(event))

    image_tag = event.get("detail", {}).get("image-tag")
    if not image_tag:
        print("No image-tag in event:", event.get("detail"))
        return {"statusCode": 400, "body": "no image-tag"}

    api_server = os.environ["EKS_ENDPOINT"]
    ca_data    = os.environ["EKS_CA_DATA"]
    token      = os.environ["K8S_SA_TOKEN"]
    namespace  = os.environ.get("NAMESPACE", "default")
    deployment = os.environ["DEPLOYMENT_NAME"]
    account    = os.environ["AWS_ACCOUNT_ID"]
    region     = os.environ["REGION"]
    repo       = os.environ["ECR_REPO_NAME"]

    image_uri = f"{account}.dkr.ecr.{region}.amazonaws.com/{repo}:{image_tag}"
    print(f" Updating deployment {deployment} → {image_uri}")

    kubeconfig = f"""
apiVersion: v1
kind: Config
clusters:
- name: eks
  cluster:
    server: {api_server}
    certificate-authority-data: {ca_data}
users:
- name: lambda-sa
  user:
    token: {token}
contexts:
- name: eks
  context:
    cluster: eks
    user: lambda-sa
current-context: eks
"""
    with open("/tmp/kubeconfig", "w") as fh:
        fh.write(kubeconfig)

    config.load_kube_config(config_file="/tmp/kubeconfig")
    api = client.AppsV1Api()

    patch_body = {
      "spec": {
        "template": {
          "spec": {
            "containers": [
              {"name": deployment, "image": image_uri}
            ]
          }
        }
      }
    }
    api.patch_namespaced_deployment(deployment, namespace, patch_body)
    print(" Deployment patched")

    anno = {"kubectl.kubernetes.io/restartedAt": context.aws_request_id}
    api.patch_namespaced_deployment(
        deployment, namespace,
        {"spec": {"template": {"metadata": {"annotations": anno}}}}
    )
    print(" Rollout restarted")

    return {"statusCode": 200, "body": f"{deployment} → {image_uri}"}

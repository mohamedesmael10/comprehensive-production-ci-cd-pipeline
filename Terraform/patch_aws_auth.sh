#!/bin/bash
set -eo pipefail

ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/comp-prod-pipeline-codebuild-role"
CURRENT_MAPROLES=$(kubectl get configmap aws-auth -n kube-system -o jsonpath="{.data.mapRoles}")

if ! echo "${CURRENT_MAPROLES}" | grep -q "${ROLE_ARN}"; then
  echo "Patching aws-auth ConfigMap..."
  NEW_ROLES=$(printf "%s\n- rolearn: %s\n  username: codebuild\n  groups:\n    - system:masters" "${CURRENT_MAPROLES}" "${ROLE_ARN}")
  kubectl patch configmap aws-auth -n kube-system --type merge -p "{\"data\":{\"mapRoles\":\"$(echo "${NEW_ROLES}" | sed 's/"/\\\"/g')\"}}"
else
  echo "IAM Role already exists in aws-auth ConfigMap."
fi


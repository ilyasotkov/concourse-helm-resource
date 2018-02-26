#!/bin/bash
set -e

setup_kubernetes() {
  payload=$1
  source=$2
  mkdir -p /root/.kube
  gcloud_auth=$(jq -r '.source.gcloud_auth // ""' < $payload)
  kubeconfig=$(jq -r '.source.kubeconfig // ""' < $payload)

  if [ -n "$gcloud_auth" ]; then
    gcloud_project=$(jq -r '.source.gcloud_project // ""' < $payload)
    gcloud_cluster=$(jq -r '.source.gcloud_cluster // ""' < $payload)
    gcloud_zone=$(jq -r '.source.gcloud_zone // ""' < $payload)

    echo "$gcloud_auth" > gcloud-auth-key.json
    gcloud --quiet auth activate-service-account --key-file gcloud-auth-key.json
    gcloud --quiet config set project $gcloud_project
    gcloud --quiet config set container/cluster $gcloud_cluster
    gcloud --quiet config set compute/zone $gcloud_zone
    gcloud --quiet container clusters get-credentials $gcloud_cluster
  elif [ -n "$kubeconfig" ]; then
    echo "$kubeconfig" > /root/.kube/config
  else
    echo "Must specify either \"gcloud_auth\" or \"kubeconfig\" for authenticating to Kubernetes."
  fi

  kubectl cluster-info
  kubectl version
}

setup_helm() {
  init_server=$(jq -r '.source.helm_init_server // "false"' < $1)
  tiller_namespace=$(jq -r '.source.tiller_namespace // "kube-system"' < $1)

  if [ "$init_server" = true ]; then
    tiller_service_account=$(jq -r '.source.tiller_service_account // "default"' < $1)
    helm init --tiller-namespace=$tiller_namespace --service-account=$tiller_service_account --upgrade
    wait_for_service_up tiller-deploy 10
  else
    helm init -c --tiller-namespace $tiller_namespace > /dev/nulll
  fi

  helm version --tiller-namespace $tiller_namespace
}

wait_for_service_up() {
  SERVICE=$1
  TIMEOUT=$2
  if [ "$TIMEOUT" -le "0" ]; then
    echo "Service $SERVICE was not ready in time"
    exit 1
  fi
  RESULT=`kubectl get endpoints --namespace=$tiller_namespace $SERVICE -o jsonpath={.subsets[].addresses[].targetRef.name} 2> /dev/null || true`
  if [ -z "$RESULT" ]; then
    sleep 1
    wait_for_service_up $SERVICE $((--TIMEOUT))
  fi
}

setup_repos() {
  repos=$(jq -r '(try .source.repos[] catch [][]) | (.name+" "+.url)' < $1)
  tiller_namespace=$(jq -r '.source.tiller_namespace // "kube-system"' < $1)

  IFS=$'\n'
  for r in $repos; do
    name=$(echo $r | cut -f1 -d' ')
    url=$(echo $r | cut -f2 -d' ')
    echo Installing helm repository $name $url
    helm repo add --tiller-namespace $tiller_namespace $name $url
  done
}

setup_resource() {
  echo "Initializing kubectl..."
  setup_kubernetes $1 $2
  echo "Initializing helm..."
  setup_helm $1
  setup_repos $1
}

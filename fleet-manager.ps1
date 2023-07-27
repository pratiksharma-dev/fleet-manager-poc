# Setup Fleet manager
az extension add --name fleet
export SUBSCRIPTION_ID="xxx"
export GROUP="fleet-manager-rg"
export FLEET="fleet-poc"

az group create --name ${GROUP} --location eastus

az fleet create --resource-group ${GROUP} --name ${FLEET} --location eastus

export MEMBER_CLUSTER_ID_1=/subscriptions/xxxx/resourceGroups/az-k8s-hmjn-poc-rg/providers/Microsoft.ContainerService/managedClusters/aks-az-k8s-hmjnpoc44
export MEMBER_NAME_1=aks-member-1

# Add members
az fleet member create \
    --resource-group ${GROUP} \
    --fleet-name ${FLEET} \
    --name ${MEMBER_NAME_1} \
    --member-cluster-id ${MEMBER_CLUSTER_ID_1}

export MEMBER_CLUSTER_ID_2=/subscriptions/xxx/resourceGroups/az-k8s-hmjn-poc-rg2/providers/Microsoft.ContainerService/managedClusters/aks-az-k8s-hmjnpoc46
export MEMBER_NAME_2=aks-member-2

az fleet member create \
    --resource-group ${GROUP} \
    --fleet-name ${FLEET} \
    --name ${MEMBER_NAME_2} \
    --member-cluster-id ${MEMBER_CLUSTER_ID_2}


# Test API access
export FLEET_ID=/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${GROUP}/providers/Microsoft.ContainerService/fleets/${FLEET}
export IDENTITY=$(az ad signed-in-user show --query "id" --output tsv)
export ROLE="Azure Kubernetes Fleet Manager RBAC Cluster Admin"
az role assignment create --role "${ROLE}" --assignee ${IDENTITY} --scope ${FLEET_ID}

az fleet get-credentials --resource-group ${GROUP} --name ${FLEET}


KUBECONFIG=fleet kubectl describe memberclusters

# Test multi cluster upgrade

az fleet updaterun create --resource-group $GROUP --fleet-name $FLEET --name test-run --upgrade-type Full --kubernetes-version 1.26.0 --stages upgrade.json

az fleet updaterun start --resource-group $GROUP --fleet-name $FLEET --name test-run

# Test object propagation
export GROUP_1="az-k8s-hmjn-poc-rg"
export GROUP_2="az-k8s-hmjn-poc-rg2"
export CLUSTER_1="aks-az-k8s-hmjnpoc44"
export CLUSTER_2="aks-az-k8s-hmjnpoc46"
az fleet get-credentials --resource-group ${GROUP} --name ${FLEET} --file fleet

az aks get-credentials --resource-group ${GROUP_1} --name ${CLUSTER_1} --file aks-member-1

az aks get-credentials --resource-group ${GROUP_2} --name ${CLUSTER_2} --file aks-member-2

KUBECONFIG=fleet kubectl create namespace hello-world

KUBECONFIG=fleet kubectl apply -f crp.yaml

KUBECONFIG=fleet kubectl get clusterresourceplacements hello-world -oyaml

KUBECONFIG=aks-member-1 kubectl get namespace hello-world

KUBECONFIG=aks-member-2 kubectl get namespace hello-world

KUBECONFIG=fleet kubectl create namespace hello-world-1

KUBECONFIG=fleet kubectl apply -f crp-1.yaml

KUBECONFIG=fleet kubectl describe memberclusters

KUBECONFIG=fleet kubectl get clusterresourceplacements hello-world-1 -oyaml

KUBECONFIG=aks-member-1 kubectl get namespace hello-world-1

KUBECONFIG=aks-member-2 kubectl get namespace hello-world-1

# Multi cluster app
KUBECONFIG=fleet kubectl create namespace kuard-demo
KUBECONFIG=fleet kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard/kuard-export-service.yaml
KUBECONFIG=fleet kubectl apply -f crp-2.yaml
KUBECONFIG=fleet kubectl get clusterresourceplacements kuard-demo -oyaml

KUBECONFIG=aks-member-1 kubectl get serviceexport kuard --namespace kuard-demo
KUBECONFIG=aks-member-2 kubectl get serviceexport kuard --namespace kuard-demo

KUBECONFIG=aks-member-1 kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard/kuard-mcs.yaml
KUBECONFIG=aks-member-1 kubectl get multiclusterservice kuard --namespace kuard-demo -oyaml


curl a.b.c.d:8080 | Select-String "addrs"

KUBECONFIG=aks-member-1 kubectl get pods -n kuard-demo -o wide

KUBECONFIG=aks-member-2 kubectl get pods -n kuard-demo -o wide
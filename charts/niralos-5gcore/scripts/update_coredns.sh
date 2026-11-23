#!/bin/bash
set -e

# 1. Privilege check and KUBECONFIG resolution for sudo
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root using: sudo bash $0"
  exit 1
fi

# Ensure kubectl can locate your user's kubeconfig under sudo
if [ -z "$KUBECONFIG" ]; then
  REAL_USER="${SUDO_USER:-$USER}"
  USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
  if [ -f "$USER_HOME/.kube/config" ]; then
    export KUBECONFIG="$USER_HOME/.kube/config"
  elif [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

CONFIG_FILE="env-configmap.yaml"
NAMESPACE="niralos"
SERVICE_NAME="dns"
UPF_POD_LABEL="app=niralos-upf"
UE_SUBNET="10.102.0.0/16"
CNI_INTERFACE="cni0"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: File '$CONFIG_FILE' not found."
  exit 1
fi

# 2. Parse MCC and MNC from env-configmap.yaml
MCC=$(grep -E '^\s*MCC:' "$CONFIG_FILE" | awk -F'"' '{print $2}')
MNC=$(grep -E '^\s*MNC:' "$CONFIG_FILE" | awk -F'"' '{print $2}')

if [ -z "$MCC" ] || [ -z "$MNC" ]; then
  echo "Error: Could not parse MCC or MNC from $CONFIG_FILE."
  exit 1
fi

PADDED_MCC=$(printf "%03d" $((10#$MCC)))
PADDED_MNC=$(printf "%03d" $((10#$MNC)))
IMS_DOMAIN="ims.mnc${PADDED_MNC}.mcc${PADDED_MCC}.3gppnetwork.org"

# 3. Query DNS Service ClusterIP dynamically
echo "Fetching ClusterIP for DNS Service in namespace '$NAMESPACE'..."
DNS_SVC_IP=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)

# Fallback 1: Query by label app=niralos-dns
if [ -z "$DNS_SVC_IP" ]; then
  DNS_SVC_IP=$(kubectl get svc -n "$NAMESPACE" -l app=niralos-dns -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || true)
fi

# Fallback 2: Any service name containing 'dns' in the namespace
if [ -z "$DNS_SVC_IP" ]; then
  DNS_SVC_IP=$(kubectl get svc -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.clusterIP}{"\n"}{end}' 2>/dev/null \
    | grep -i 'dns' | awk 'NR==1 {print $2}')
fi

if [ -z "$DNS_SVC_IP" ]; then
  echo "Error: Could not retrieve DNS Service IP. Available services in '$NAMESPACE':"
  kubectl get svc -n "$NAMESPACE"
  exit 1
fi

echo "MCC: ${MCC} -> ${PADDED_MCC}"
echo "MNC: ${MNC} -> ${PADDED_MNC}"
echo "IMS Domain: ${IMS_DOMAIN}"
echo "Discovered DNS Service IP: ${DNS_SVC_IP}"

# 4. Apply updated CoreDNS ConfigMap
cat <<CONFIG | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    ${IMS_DOMAIN}:53 {
        errors
        cache 30
        forward . ${DNS_SVC_IP}
    }
    e164.arpa:53 {
        errors
        cache 30
        forward . ${DNS_SVC_IP}
    }
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30 {
           disable success cluster.local
           disable denial cluster.local
        }
        loop
        reload
        loadbalance
    }
CONFIG

# 5. Restart CoreDNS
echo "Restarting CoreDNS in kube-system..."
kubectl rollout restart -n kube-system deployment/coredns
kubectl rollout status -n kube-system deployment/coredns

# 6. Restart NiralOS DNS StatefulSet
echo "Restarting DNS StatefulSet in '$NAMESPACE'..."

NIRALOS_DNS_STS=$(kubectl get statefulset -n "$NAMESPACE" \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  | grep -i 'dns' | head -n 1 || true)

if [ -n "$NIRALOS_DNS_STS" ]; then
    echo "Found DNS StatefulSet: $NIRALOS_DNS_STS"
    echo "Restarting..."

    kubectl rollout restart statefulset/"$NIRALOS_DNS_STS" -n "$NAMESPACE"

    kubectl rollout status statefulset/"$NIRALOS_DNS_STS" \
        -n "$NAMESPACE" \
        --timeout=120s

    echo "DNS StatefulSet restarted successfully."
else
    echo "ERROR: No DNS StatefulSet found in namespace '$NAMESPACE'."
    kubectl get statefulset -n "$NAMESPACE"
    exit 1
fi

# 7. Discover UPF Pod IP
echo "Discovering UPF Pod IP in namespace '$NAMESPACE'..."
UPF_POD_IP=$(kubectl get pods -n "$NAMESPACE" -l "$UPF_POD_LABEL" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || true)

# Fallback: Find running pod containing 'upf' in name
if [ -z "$UPF_POD_IP" ]; then
  UPF_POD_IP=$(kubectl get pods -n "$NAMESPACE" \
    --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}' 2>/dev/null \
    | grep -i 'upf' | awk 'NR==1 {print $2}')
fi

if [ -z "$UPF_POD_IP" ]; then
  echo "Error: Could not retrieve running UPF Pod IP. Running pods in '$NAMESPACE':"
  kubectl get pods -n "$NAMESPACE"
  exit 1
fi

echo "Discovered UPF Pod IP: ${UPF_POD_IP}"

# Verify CNI interface exists on host
if ! ip link show "$CNI_INTERFACE" > /dev/null 2>&1; then
  DETECTED_DEV=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(cni0|flannel\.|cilium_)' | head -n 1)
  if [ -n "$DETECTED_DEV" ]; then
    CNI_INTERFACE="$DETECTED_DEV"
  fi
fi

# 8. Apply Route, sysctl forwarding, and iptables rules
echo "Configuring route: ${UE_SUBNET} via ${UPF_POD_IP} dev ${CNI_INTERFACE}..."
ip route replace "${UE_SUBNET}" via "${UPF_POD_IP}" dev "${CNI_INTERFACE}"

echo "Enabling IPv4 forwarding..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null

echo "Applying iptables FORWARD rules for ${UE_SUBNET}..."
if ! iptables -C FORWARD -s "${UE_SUBNET}" -j ACCEPT 2>/dev/null; then
  iptables -I FORWARD -s "${UE_SUBNET}" -j ACCEPT
fi

if ! iptables -C FORWARD -d "${UE_SUBNET}" -j ACCEPT 2>/dev/null; then
  iptables -I FORWARD -d "${UE_SUBNET}" -j ACCEPT
fi

echo "---"
echo "CoreDNS, NiralOS DNS, UPF routing, and firewall rules configured successfully."
# NiralOS Edge App Store

Helm chart repository for NiralOS Edge applications.

## Repository URL

After GitHub Pages is enabled from the `gh-pages` branch:

```bash
helm repo add niralos-edge-app-store https://niral-networks.github.io/niralos-edge-app-store/
helm repo update
helm search repo niralos-edge-app-store
```

## Available Applications

### 1. Niral One

Niral One is a highly extensible, self-hosted AI platform designed to centralize your entire artificial intelligence workflow.

```bash
helm upgrade --install niral-one niralos-edge-app-store/niral-one \
  --namespace niral-one \
  --create-namespace \
  --set-string webui.secretKey="replace-with-a-strong-secret"
```

### 2. NiralOS 5G Core

NiralOS 5G Core is a cloud-native, carrier-grade private 5G core network platform (3GPP Release 16 compliant) with integrated IMS and edge UPF.

#### Prerequisites
- Kubernetes cluster with Multus CNI installed.
- Host network interface for macvlan (e.g., `eth0` or `enp6s19`).
- DockerHub registry credentials with access to `niralnetworks` images.

#### Install

```bash
helm upgrade --install niralos-5g niralos-edge-app-store/niralos-5gcore \
  --namespace niralos \
  --create-namespace \
  --set networking.macvlan.master="<your-host-interface>" \
  --set secrets.dockerRegistry.password="<your-dockerhub-token>"
```

## Repository layout

```text
assets/
  icon.png                  # Niral One icon
  niralos-5gcore-icon.png   # NiralOS 5G Core icon
charts/
  niral-one/
    Chart.yaml
    values.yaml
    templates/
  niralos-5gcore/
    Chart.yaml
    values.yaml
    templates/
```

Chart releases are generated automatically by `.github/workflows/release-charts.yml`.
For every new release, increment `version:` in the chart's `Chart.yaml`.

# NiralOS Edge App Store

Helm chart repository for NiralOS Edge applications.

## Repository URL

After GitHub Pages is enabled from the `gh-pages` branch:

```bash
helm repo add niralos-edge-app-store https://niral-networks.github.io/niralos-edge-app-store/
helm repo update
helm search repo niralos-edge-app-store
```

## Install Niral One

```bash
helm upgrade --install niral-one niralos-edge-app-store/niral-one \
  --namespace niral-one \
  --create-namespace \
  --set-string webui.secretKey="replace-with-a-strong-secret"
```

## Repository layout

```text
charts/
  niral-one/
    Chart.yaml
    values.yaml
    templates/
```

Chart releases are generated automatically by `.github/workflows/release-charts.yml`.
For every new release, increment `version:` in the chart's `Chart.yaml`.

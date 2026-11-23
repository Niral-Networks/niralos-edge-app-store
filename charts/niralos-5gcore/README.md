# Niralos 5G Core Helm Chart

Converted from the supplied `niralos-kubernetes-deploy(2).zip`.

## Values mapping

- `coreNetwork`: MCC, MNC, TAC, plmnList, slices (with mapped DNNs), and dnns (with IP pools/TUN interfaces)
- `networking`: Multus/macvlan master/mode and UPF/N3IWF secondary IPs
- `workloadEnv.upf`: UPF advertised IP and other workload environment values
- `images`: source container images/tags
- `replicas`: source replica counts
- `services`: source Service types, ports, protocols, nodePorts and externalIPs
- `storage`: source StorageClass/PVC sizes and source hostPath values
- `coreEnv`: source `env-configmap.yaml` values, with MCC/MNC driven from `coreNetwork`
- `secrets`: Docker registry credentials, TLS, database/app credentials and other source credentials

The original resource names are retained, including `nirfalos-nssf-1` from the source service manifest.

### Configuring Multiple Slices, DNNs, and PLMNs

You can configure any number of network slices, data network names (DNNs), and supported PLMNs directly in `values.yaml`:

```yaml
coreNetwork:
  plmn:
    mcc: '001'
    mnc: '01'
  tai:
    tac: [1, 2, 3] # or single: tac: 1, or tac: [1, 3, 5]
  plmnList:
    - mcc: '001'
      mnc: '01'
    # - mcc: '310'
    #   mnc: '410'
  service_id: "001"
  imsvops: 1 # 1 = VoNR enabled, 0 = VoNR disabled (data-only / EPS fallback)
  slices:
    - sst: 1
      sd: '000001'
      dnns:
        - internet
        - ims
    - sst: 1
      sd: '000002'
      dnns:
        - internet
    - sst: 2
      sd: '000003'
      dnns:
        - internet
  dnns:
    - name: internet
      cidr: 10.101.0.0/16
      gateway: 10.101.0.1
      dev: niralos-gw
      nat: true
    - name: ims
      cidr: 10.102.0.0/16
      gateway: 10.102.0.1
      dev: niralos-gw2
      nat: false
```


## Install

```bash
helm lint .
helm template niralos . -n niralos -f values.yaml > rendered.yaml
kubectl apply --dry-run=server -f rendered.yaml
helm upgrade --install niralos . -n niralos --create-namespace -f values.yaml
```

## Important

`values.yaml` contains credentials copied from the supplied source manifest because they were explicitly requested to remain there. Do not commit this file to a public repository. The supplied Docker registry credential should be rotated if it is a live token.

# helm-charts

Helm charts for wger deployment on Kubernetes

## Quickstart

```bash
git clone https://github.com/wger-project/helm-charts.git
helm dependency update
helm upgrade --install wger . --namespace wger --create-namespace
```

## Uninstalling

To uninstall a deployment called `wger`:

```bash
helm delete wger
```

# Hack

`generate.sh` renders the manifests in `agent/`, `host/` and `k3s/` from the kargo-enterprise chart:

```
CHART_PATH=~/ws/akuityio/kargo-enterprise/charts/kargo-enterprise \
IMAGE_REPO=ghcr.io/jessesuen/kargo \
IMAGE_TAG=fleet \
AGENT_NAMESPACE=akuity-demo-fleet \
AGENT_NAME=demo-fleet \
HOST_NAMESPACE=kargo-u4mqjepdv1rr4us5 \
  ./hack/generate.sh
```

Optional override: `LOG_LEVEL` (default `DEBUG`).

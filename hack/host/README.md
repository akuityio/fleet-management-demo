
# Hack

```
kubectl -n kargo-u4mqjepdv1rr4us5 patch networkpolicy k3s --type=json -p '[
  {"op":"add","path":"/spec/ingress/-","value":{
    "from":[{"podSelector":{"matchLabels":{
      "app.kubernetes.io/component":"promotion-request-controller",
      "app.kubernetes.io/name":"kargo-enterprise"}}}],
    "ports":[{"port":6443,"protocol":"TCP"}]}}
]'
```
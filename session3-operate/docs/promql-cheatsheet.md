# Queries to try in Grafana (Explore, then the Managed Prometheus data source)

Request rate by status code (from the demo app):

    sum by (code) (rate(demo_http_requests_total[5m]))

Error ratio (what the DemoAppHighErrorRate alert uses):

    sum(rate(demo_http_requests_total{code=~"5.."}[5m])) / sum(rate(demo_http_requests_total[5m]))

95th percentile latency:

    histogram_quantile(0.95, sum by (le) (rate(demo_http_request_duration_seconds_bucket[5m])))

Pods that restarted recently (from kube-state-metrics):

    increase(kube_pod_container_status_restarts_total{namespace="ops-demo"}[15m])

Ready replicas versus desired (watch this during the game day):

    kube_deployment_status_replicas_ready{namespace="ops-demo"}
    kube_deployment_spec_replicas{namespace="ops-demo"}

CPU use compared with the request (right-sizing):

    sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="ops-demo",container="app"}[5m]))
    sum by (pod) (kube_pod_container_resource_requests{namespace="ops-demo",resource="cpu"})

Note: exact metric names depend on what the managed Prometheus add-on collects by default.
If a query returns nothing, open the metrics browser in Grafana and search for the name.

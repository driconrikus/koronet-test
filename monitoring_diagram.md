# Monitoring Proposal Diagram

This diagram illustrates a high-level monitoring setup for the web server and Redis running in Docker/ECS using Prometheus and Grafana.

```
+-----------------------+
|      AWS ECS Cluster  |
|                       |
|  +-----------------+  |
|  |   ECS Service   |  |
|  | (Web Server)    |  |
|  |  (Task)         |  |
|  | +-------------+ |  |
|  | | Application | |  |
|  | | (Flask App) |<----+ Collects metrics
|  | +-------------+ |  |
|  |                 |  |
|  | +-------------+ |  |
|  | | Sidecar     |<----+ Exports application metrics
|  | | (Prometheus)| |  |
|  | +-------------+ |  |
|  +-----------------+  |
|                       |
|  +-----------------+  |
|  |   ECS Service   |  |
|  | (Redis)         |  |
|  |  (Task)         |  |
|  | +-------------+ |  |
|  | | Redis       |<----+ Exposes Redis metrics
|  | | Container   | |  |
|  | +-------------+ |  |
|  | +-------------+ |  |
|  | | Sidecar     |<----+ Exports Redis metrics
|  | | (Prometheus)| |  |
|  | +-------------+ |  |
|  +-----------------+  |
+-----------------------+
        |    ^
        |    |
        |    |
        V    |
+-----------------------+
|      Prometheus       |<----+ Scrapes metrics from ECS service sidecars
|      (Running on EC2/  |
|      separate ECS     |
|      service)         |
+-----------------------+
        |    ^
        |    |
        |    |
        V    |
+-----------------------+
|       Grafana         |<----+ Queries Prometheus for data, displays dashboards
|       (Running on EC2/ |
|       separate ECS    |
|       service)        |
+-----------------------+

```

**Explanation:**

1.  **Web Server (Flask App)**: The Flask application runs within an ECS task.
2.  **Redis Container**: The Redis instance runs within another ECS task.
3.  **Sidecar (Prometheus Exporter)**: For both the web server and Redis, a sidecar container running a Prometheus exporter will be deployed alongside them in the same ECS task. This sidecar will expose metrics from the main application/service. For Flask, a client library like `prometheus_client` would be integrated into the application to expose custom metrics. For Redis, an official Redis Exporter can be used.
4.  **Prometheus**: A dedicated Prometheus instance (running on an EC2 instance or as a separate ECS service) will be configured to discover and scrape metrics from the Prometheus exporters (sidecars) running in the ECS services. It will store these metrics in its time-series database.
5.  **Grafana**: Grafana will be used for visualization and alerting. It will connect to Prometheus as a data source and allow the creation of dashboards to monitor the web server and Redis performance, health, and custom application metrics.
6.  **AWS ECS Cluster**: All services (web server, Redis, and potentially Prometheus/Grafana themselves) will run within an AWS ECS cluster.

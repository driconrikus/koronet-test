# Monitoring Proposal Diagram

This diagram illustrates a high-level monitoring setup for the web server and Redis running in Docker/ECS using Prometheus and Grafana.

```
+-------------------------------------------------------------+
|                   AWS ECS Cluster (koronet-ecs-cluster)     |
|                                                             |
|  +--------------------+   +--------------------+           |
|  | ECS Service        |   | ECS Service        |           |
|  | (Web Server)       |   | (PostgreSQL)       |           |
|  | (Task)             |   | (Task)             |           |
|  | +----------------+ |   | +----------------+ |           |
|  | | Flask App      |<--+ | | PostgreSQL     | |           |
|  | +----------------+ |   | +----------------+ |           |
|  |                    |   |                    |           |
|  | +----------------+ |   | +----------------+ |           |
|  | | Node Exporter  |<----+ | PG Exporter    |<----------+
|  | | (Sidecar)      | |   | | (Sidecar)      | |           |
|  | +----------------+ |   | +----------------+ |           |
|  +--------------------+   +--------------------+           |
|                                                             |
|  +--------------------+                                     |
|  | ECS Service        |                                     |
|  | (Redis)            |                                     |
|  | (Task)             |                                     |
|  | +----------------+ |                                     |
|  | | Redis          |<------------------------------------+
|  | +----------------+ |                                     |
|  |                    |                                     |
|  | +----------------+ |                                     |
|  | | Redis Exporter |<-----------------------------------+|
|  | | (Sidecar)      | |                                   ||
|  | +----------------+ |                                   ||
|  +--------------------+                                   ||
|                                                             ||
|  +-------------------------------------------------------+  ||
|  | ECS Service (Prometheus)                              |  ||
|  | (Task)                                                |<-------------- Scrapes metrics (Service Discovery)
|  | +---------------------------------------------------+ |  ||
|  | | Prometheus Server (Scrapes :9100, :9187, :9121) | |  ||
|  | +---------------------------------------------------+ |  ||
|  +-------------------------------------------------------+  ||
|        |                                                    ||
|        | Queries                                            ||
|        V                                                    ||
|  +-------------------------------------------------------+  ||
|  | ECS Service (Grafana)                                 |  ||
|  | (Task)                                                |<---------- Accesses dashboards (:3000)
|  | +---------------------------------------------------+ |  ||
|  | | Grafana Web UI (Data Source: Prometheus :9090)  | |  ||
|  | +---------------------------------------------------+ |  ||
|  +-------------------------------------------------------+  ||
+-------------------------------------------------------------+

```

**Explanation:**

1.  **AWS ECS Cluster (`koronet-ecs-cluster`)**: All services (Web Server, PostgreSQL, Redis, Prometheus, Grafana) run within this cluster on AWS Fargate.
2.  **Web Server (Flask App) with Node Exporter Sidecar**: The Flask application runs in an ECS task. A `Node Exporter` sidecar container runs alongside it, exposing host-level metrics on port `9100`.
3.  **PostgreSQL with PostgreSQL Exporter Sidecar**: The PostgreSQL database runs in an ECS task. A `PostgreSQL Exporter` sidecar container (e.g., `wrouesnel/postgres_exporter`) runs alongside it, exposing database metrics on port `9187`.
4.  **Redis with Redis Exporter Sidecar**: The Redis instance runs in an ECS task. A `Redis Exporter` sidecar container (e.g., `oliver006/redis_exporter`) runs alongside it, exposing Redis metrics on port `9121`.
5.  **Prometheus**: A dedicated `Prometheus` instance runs as its own ECS service. It is configured with `AWS Service Discovery` to automatically discover and scrape metrics from the Node Exporter, PostgreSQL Exporter, and Redis Exporter sidecars within the private DNS namespace (`koronet.local`) on their respective ports (`9100`, `9187`, `9121`). Prometheus stores these metrics.
6.  **Grafana**: `Grafana` runs as its own ECS service. It is configured to query the `Prometheus` service (using its internal service discovery hostname `koronet-prometheus-service.koronet.local:9090`) as a data source. Grafana provides dashboards for visualizing the collected metrics and for setting up alerts.
7.  **Service Discovery**: AWS Cloud Map (via `aws_service_discovery_private_dns_namespace` and `aws_service_discovery_service` resources in Terraform) provides internal DNS resolution, allowing services to find each other using short hostnames within the VPC (e.g., `koronet-prometheus-service.koronet.local`).

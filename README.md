# Koronet Backend Service and Infrastructure

This repository contains a robust backend service with a relational database (PostgreSQL), an in-memory data store (Redis), and a comprehensive monitoring solution using Prometheus and Grafana, all deployed on AWS Elastic Container Service (ECS) using Terraform and managed with a GitHub Actions CI/CD pipeline. This project provides the core backend and operational infrastructure required for a full-stack application.

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Local Development](#local-development)
- [AWS ECS Deployment with Terraform](#aws-ecs-deployment-with-terraform)
- [CI/CD Pipeline with GitHub Actions](#ci/cd-pipeline-with-github-actions)
- [Monitoring with Prometheus and Grafana](#monitoring-with-prometheus-and-grafana)
- [Prerequisites](#prerequisites)

## Project Overview

This project aims to provide a robust and scalable backend service with database and caching capabilities, coupled with automated deployment and observability. It lays the groundwork for a full-stack application. The core components include:

*   **Flask Web Server**: A Python Flask application that responds with "Hi Koronet Team." and reports connectivity status to PostgreSQL and Redis.
*   **PostgreSQL Database**: A relational database for persistent data storage.
*   **Redis**: An in-memory data store for caching and session management.
*   **AWS ECS (Fargate)**: The cloud platform for container orchestration, utilizing AWS Fargate for serverless compute.
*   **Terraform**: Infrastructure as Code (IaC) for provisioning and managing all AWS resources.
*   **GitHub Actions**: A CI/CD pipeline for automating the build, testing, and deployment processes.
*   **Prometheus & Grafana**: A comprehensive monitoring stack for collecting, storing, and visualizing metrics from all services.

## Architecture

The application is designed with a microservices-like architecture, with each core component running as a separate service within an AWS ECS cluster. AWS Service Discovery (Cloud Map) is used for inter-service communication. Monitoring is achieved by deploying Prometheus and Grafana as separate ECS services, which scrape metrics from sidecar exporters running alongside the application, database, and cache.

(Refer to `monitoring_diagram.md` for a visual representation of the monitoring architecture.)

## Local Development

To run the application locally using Docker Compose:

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/driconrikus/koronet-test.git
    cd koronet-test
    ```

2.  **Build and run with Docker Compose:**
    ```bash
    docker-compose up --build
    ```

3.  **Access the application:** Open your browser to `http://localhost:5000`.
    You should see the message "Hi Koronet Team. DB Status: Connected. Redis Status: Connected."

## AWS ECS Deployment with Terraform

This project uses Terraform to provision the necessary AWS infrastructure for deploying the application to an ECS Fargate cluster. This includes:

*   VPC, Subnets, Internet Gateway, Route Tables
*   Security Groups for inter-service communication and external access
*   ECS Cluster
*   IAM Roles for ECS task execution
*   CloudWatch Log Groups for all services
*   ECS Task Definitions and Services for the Web Server, PostgreSQL, Redis, Prometheus, and Grafana
*   AWS Service Discovery (Cloud Map) for internal DNS resolution

**Deployment Steps:**

1.  **Configure AWS CLI**: Ensure your AWS CLI is configured with appropriate credentials and default region.

2.  **Navigate to the Terraform directory:**
    ```bash
    cd terraform
    ```

3.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

4.  **Create a Terraform plan (optional, but recommended):**
    ```bash
    terraform plan -var='docker_username=YOUR_DOCKER_USERNAME' -var='db_name=koronet_db' -var='db_user=koronet_user' -var='db_password=koronet_password' -var='redis_port=6379' -var='grafana_admin_user=admin' -var='grafana_admin_password=YOUR_GRAFANA_PASSWORD'
    ```
    *Replace placeholder values with your actual Docker Hub username and desired Grafana password.*

5.  **Apply the Terraform configuration:**
    ```bash
    terraform apply -auto-approve -var='docker_username=YOUR_DOCKER_USERNAME' -var='db_name=koronet_db' -var='db_user=koronet_user' -var='db_password=koronet_password' -var='redis_port=6379' -var='grafana_admin_user=admin' -var='grafana_admin_password=YOUR_GRAFANA_PASSWORD'
    ```
    *Again, replace placeholder values.*

6.  **Retrieve Service Endpoints:** After successful deployment, you can find the public IP addresses of your web server and Grafana services in the AWS ECS console or by using AWS CLI commands (e.g., `aws ecs describe-services ...`).

## CI/CD Pipeline with GitHub Actions

The `.github/workflows/ci.yml` file defines a GitHub Actions workflow that automates the following:

1.  **Build Docker Images**: Builds Docker images for the Flask web server and the custom Prometheus image (from `terraform/Dockerfile.prometheus`).
2.  **Run Tests**: Executes unit tests for the Flask application.
3.  **Push to Docker Hub**: Pushes the built Docker images to Docker Hub.
4.  **Deploy to ECS**: Updates all ECS services (web server, PostgreSQL, Redis, Prometheus, Grafana) to use the latest task definitions and forces new deployments.

**To enable the CI/CD pipeline:**

1.  **Configure GitHub Secrets**: Go to your GitHub repository settings -> `Secrets` and add the following repository secrets:
    *   `DOCKER_USERNAME`: Your Docker Hub username.
    *   `DOCKER_PASSWORD`: Your Docker Hub Access Token (generated from Docker Hub Security settings if using Google login).
    *   `AWS_ACCESS_KEY_ID`: Your AWS Access Key ID with permissions to deploy to ECS.
    *   `AWS_SECRET_ACCESS_KEY`: Your AWS Secret Access Key.

2.  **Push Changes**: Any push to the `main` branch will trigger this workflow.

## Monitoring with Prometheus and Grafana

The project includes a robust monitoring stack:

*   **Prometheus**: Deployed as an ECS service, configured via `terraform/prometheus.yml` (embedded in a custom Docker image) to scrape metrics from:
    *   **Node Exporter** (sidecar with Web Server) on port `9100`.
    *   **PostgreSQL Exporter** (sidecar with PostgreSQL) on port `9187`.
    *   **Redis Exporter** (sidecar with Redis) on port `9121`.
*   **Grafana**: Deployed as an ECS service, accessible via its public IP on port `3000`. It connects to the Prometheus service (using `http://koronet-prometheus-service.koronet.local:9090`) as a data source to visualize metrics through dashboards.

**Accessing Grafana:**

1.  **Retrieve Grafana Public IP**: Find the public IP of your Grafana ECS service (e.g., from AWS ECS console).
2.  **Open in Browser**: Navigate to `http://<GRAFANA_PUBLIC_IP>:3000`.
3.  **Login**: Use the `grafana_admin_user` (default: `admin`) and `grafana_admin_password` (the value you provided during `terraform apply`) to log in.
4.  **Configure Prometheus Data Source**: Ensure the Prometheus data source URL in Grafana is set to `http://koronet-prometheus-service.koronet.local:9090`.

## Prerequisites

Before you begin, ensure you have the following installed and configured:

*   **Docker Desktop**: For local development (`docker` and `docker-compose`).
*   **Python 3.9+**: For running the Flask application and tests.
*   **pip**: Python package installer.
*   **AWS Account**: An active AWS account with sufficient permissions to create ECS, VPC, IAM, CloudWatch, and Service Discovery resources.
*   **AWS CLI**: Configured with your AWS credentials.
*   **Terraform CLI**: Version `~> 1.0` or later.
*   **GitHub Account**: For using GitHub Actions.
*   **Docker Hub Account**: For storing Docker images (or another container registry). If using Google login, generate an [Access Token](https://hub.docker.com/settings/security/access-tokens) for `DOCKER_PASSWORD`.

## Troubleshooting

### Local Development: `address already in use` error

If you encounter an error like `Error response from daemon: Ports are not available: exposing port TCP 0.0.0.0:5000 -> 127.0.0.1:0: listen tcp 0.0.0.0:5000: bind: address already in use` when running `docker-compose up`, it means another process on your local machine is already using the required port (`5000`).

To resolve this (on macOS):

1.  **Find the process using port 5000:**
    Open your terminal and run:
    ```bash
    sudo lsof -i TCP:5000
    ```
2.  **Identify the culprit:** Note the `PID` (Process ID) from the output (e.g., `12345`) and the `COMMAND`.
3.  **Stop the process:**
    ```bash
    kill -9 <PID>
    ```
    Replace `<PID>` with the actual process ID you found (e.g., `kill -9 12345`).

After stopping the conflicting process, try running `docker-compose up --build` again.


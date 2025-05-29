# DogfyDiet Cloud Platform 🐕🍲

Welcome to the DogfyDiet Cloud Platform, a full-stack serverless and microservices-based application built on Google Cloud Platform (GCP). This project showcases modern cloud architecture, Infrastructure as Code (IaC) with Terraform, and CI/CD best practices for a scalable, secure, and observable system.

The primary goal of this platform is to provide a robust foundation for deploying and managing a full-stack application, consisting of a user-facing frontend and a backend built with microservices that communicate asynchronously.

## 📄 Project Documentation

For detailed information, please refer to the documentation in the `docs/` directory:

* **[Architecture Overview (`docs/architecture.md`)](docs/architecture.md)**: In-depth explanation of the system design, components, and data flow.
* **[Technical Decisions (`docs/technical_decisions.md`)](docs/technical_decisions.md)**: Rationale behind key technology and architectural choices.
* **[Deployment Guide (`docs/deployment_guide.md`)](docs/deployment_guide.md)**: Step-by-step instructions for setting up and deploying the platform.
* **[CI/CD Pipeline (`docs/ci_cd.md`)](docs/ci_cd.md)**: Information on the CI/CD setup and automation.
* **[Security Practices (`docs/security_practices.md`)](docs/security_practices.md)**: Overview of implemented security measures.
* **[Monitoring & Observability (`docs/monitoring_observability.md`)](docs/monitoring_observability.md)**: Details on logging, monitoring, and alerting.
* **[Production Readiness & Next Steps (`docs/production_readiness.md`)](docs/production_readiness.md)**: Analysis of current status, missing components, and considerations for a production environment.
* **[Troubleshooting Guide (`docs/troubleshooting.md`)](docs/troubleshooting.md)**: Tips for resolving common issues.

## ✨ Core Features

* **Microservices Architecture**: Backend powered by Node.js microservices on Google Kubernetes Engine (GKE).
* **Event-Driven**: Asynchronous communication using Google Pub/Sub.
* **Serverless Frontend**: Vue.js 3 SPA hosted on Google Cloud Storage, delivered via CDN and HTTP(S) Load Balancer.
* **NoSQL Database**: Scalable data persistence with Google Firestore.
* **Infrastructure as Code**: Entire infrastructure provisioned and managed by Terraform. 
* **Containerization**: Applications containerized with Docker and deployed using Helm.
* **Comprehensive Security**: Workload Identity, Secret Manager, IAM best practices. 
* **Built-in Observability**: Leveraging Google Cloud Monitoring and Logging. 

## 🚀 Technology Stack

* **Cloud**: Google Cloud Platform (GKE, Pub/Sub, Firestore, GCS, Load Balancing, Artifact Registry, Secret Manager, Cloud Monitoring)
* **IaC**: Terraform
* **Backend**: Node.js, Express.js
* **Frontend**: Vue.js 3
* **Containerization**: Docker, Helm
* **CI/CD**: Structured for automation (e.g., GitHub Actions or CircleCI) 

## 🛠️ Quick Start

1.  **Prerequisites**: Ensure you have `gcloud` CLI, `terraform`, `kubectl`, `helm`, `docker`, and Node.js installed and configured.
2.  **Clone**: `git clone https://github.com/your-username/dogfydiet-platform.git && cd dogfydiet-platform`
3.  **Bootstrap (Recommended)**:
    ```bash
    chmod +x scripts/bootstrap.sh
    ./scripts/bootstrap.sh
    ```
    *(This script helps set up the Terraform backend GCS bucket and a CI/CD service account. Configure GitHub secrets as prompted by the script for CI/CD automation.)*
4.  **Configure**: Update `terraform/environments/dev/terraform.tfvars` and the backend configuration in `terraform/environments/dev/main.tf` if not using the bootstrap script's defaults.
5.  **Deploy Infrastructure**:
    ```bash
    cd terraform/environments/dev
    terraform init
    terraform plan
    terraform apply
    ```
6.  **Deploy Applications**: Follow the detailed steps in the **[Deployment Guide (`docs/deployment_guide.md`)](docs/deployment_guide.md)** to build and deploy the frontend and backend microservices.

For detailed commands, application deployment, and CI/CD setup, please refer to the **[Deployment Guide (`docs/deployment_guide.md`)](docs/deployment_guide.md)** and **[CI/CD Pipeline (`docs/ci_cd.md`)](docs/ci_cd.md)**.

## 🏗️ Project Structure

```bash
dogfydiet-platform/
├── README.md                     # This file
├── .github/workflows/           # (Placeholder) GitHub Actions CI/CD pipelines
├── applications/                # Application source code
│   ├── frontend/               # Vue.js frontend application
│   ├── microservice-1/         # API Gateway & Publisher
│   └── microservice-2/         # Subscriber & Data Processor
├── docs/                        # Detailed documentation
│   ├── architecture.md
│   ├── deployment_guide.md
│   └── ... (other docs)
├── k8s/                        # Kubernetes manifests and Helm charts
│   └── helm-charts/
├── scripts/                    # Utility scripts (e.g., bootstrap.sh)
├── terraform/                  # Infrastructure as Code
│   ├── environments/dev/
│   └── modules/
├── CONTRIBUTING.md             # Contribution guidelines
├── LICENSE                     # Project License
└── Makefile                    # Makefile for common tasks
```



## 🤝 Contributing

Contributions are welcome! Please refer to the **[CONTRIBUTING.md (`CONTRIBUTING.md`)](CONTRIBUTING.md)** guidelines.

## 📄 License

This project is licensed under the MIT License. See the **[LICENSE (`LICENSE`)](LICENSE)** file for details.

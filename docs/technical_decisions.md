# Technical Decisions and Rationale

This document outlines the key technical decisions made during the design and implementation of the DogfyDiet Cloud Platform and the reasoning behind them.

### 1. Infrastructure as Code: Terraform
* **Decision**: Use Terraform for provisioning all GCP infrastructure.
* **Rationale**:
    * **Industry Standard**: Terraform is a widely adopted, declarative IaC tool.
    * **Version Control**: Enables infrastructure configurations to be version-controlled alongside application code.
    * **Repeatability & Consistency**: Ensures consistent environments across deployments (dev, staging, prod).
    * **Modularity**: The project uses Terraform modules for reusability and better organization of resources like VPC, GKE, Pub/Sub, etc.
    * **Ecosystem**: Strong community support and extensive GCP provider coverage.

### 2. Compute for Backend: Google Kubernetes Engine (GKE)
* **Requirement**: "GKE cluster or individual compute instances for deploying backend microservices".
* **Decision**: Utilize GKE for deploying backend microservices.
* **Rationale**:
    * **Managed Kubernetes**: GKE abstracts away much of the Kubernetes control plane management.
    * **Scalability**: Provides robust autoscaling for both pods (Horizontal Pod Autoscaler) and nodes (Cluster Autoscaler).
    * **Container Orchestration**: Simplifies deployment, service discovery, load balancing, and self-healing of containerized applications.
    * **Resource Efficiency**: Containers allow for denser packing of applications compared to traditional VMs.
    * **DevOps Practices**: Aligns with modern DevOps by using declarative configurations (Helm charts) for application deployment.
    * **GCP Integration**: Seamless integration with Workload Identity, GCP Load Balancing (via NEGs), and Cloud Monitoring.

### 3. Frontend Hosting: Google Cloud Storage (GCS) with CDN
* **Requirement**: "Managed Instance Group with autoscaling to serve the frontend application".
* **Decision**: Host the Vue.js static SPA on GCS, served via HTTP(S) Load Balancer with Cloud CDN enabled.
* **Rationale**:
    * **Cost-Effectiveness**: Significantly cheaper for static content delivery compared to running VMs in a MIG.
    * **Scalability & Performance**: GCS offers massive scalability, and Cloud CDN provides global caching for low-latency access.
    * **Simplicity**: Simpler to manage than a MIG for static files; no OS patching or instance management required.
    * **Best Practice for SPAs**: This is a standard and recommended GCP architecture for serving static SPAs.
    * **Deviation Justification**: While the requirement mentioned a MIG, GCS + CDN is a more appropriate and efficient solution for a purely static frontend. A MIG would be considered if the frontend required server-side rendering (SSR) capabilities not achievable through pre-rendering at build time.

### 4. Messaging Service: Google Pub/Sub
* **Requirement**: "A message service to intercommunicate 2 microservices".
* **Decision**: Use Google Pub/Sub for asynchronous event-driven communication.
* **Rationale**:
    * **Decoupling**: Allows Microservice 1 (publisher) and Microservice 2 (subscriber) to operate independently.
    * **Asynchronous Processing**: Improves responsiveness of Microservice 1 by offloading tasks.
    * **Scalability & Reliability**: Pub/Sub is a globally scalable and durable messaging service.
    * **Resilience**: Supports features like retries and dead-letter topics (DLT), which are configured in this project, enhancing fault tolerance.

### 5. Database: Google Firestore
* **Requirement**: "A non-relational database".
* **Decision**: Use Google Firestore in Native Mode.
* **Rationale**:
    * **Serverless & Scalable**: Automatically handles scaling, sharding, and replication.
    * **Flexible Schema**: Document-based model accommodates evolving data structures common in agile development.
    * **Ease of Use**: Provides SDKs that are straightforward to integrate into applications (as seen in Microservice 2).
    * **GCP Integration**: Strong integration with IAM and other GCP services.
    * **Real-time Potential**: Offers real-time update capabilities, which could be leveraged for future frontend enhancements.

### 6. Container Registry: Google Artifact Registry
* **Requirement**: Build and push Docker images to Google Container Registry or Artifact Registry.
* **Decision**: Use Google Artifact Registry.
* **Rationale**:
    * **Successor to GCR**: Artifact Registry is GCP's recommended service for managing container images and other artifacts.
    * **Regional Repositories**: Provides better control over data locality.
    * **IAM Integration**: Fine-grained access control using GCP IAM.
    * **Versatility**: Can store various artifact types beyond Docker images (e.g., Maven, npm).

### 7. Secrets Management: Google Secret Manager
* **Requirement**: "Secure secret management using Google Secret Manager".
* **Decision**: Employ Google Secret Manager for storing sensitive information like service account keys (primarily for CI/CD).
* **Rationale**:
    * **Secure Storage**: Provides a centralized and secure place to store secrets.
    * **Access Control**: Integrates with IAM for granular control over who/what can access secrets.
    * **Versioning**: Supports versioning of secrets.
    * **Audit Logging**: Logs access to secrets.
    * **Note on GKE**: For applications running on GKE, Workload Identity is the preferred method to access other GCP services, avoiding the need to mount service account keys as secrets into pods. Secret Manager is primarily used here for the CI/CD pipeline's service account key.

### 8. CI/CD Automation: (CircleCI vs. GitHub Actions)
* **Requirement**: "Configure a deployment pipeline using CircleCI".
* **Current Status**: GitHub Actions over CircleCI.
* **Rationale**:
    * **Integration**: Deeply integrated with GitHub repositories.
    * **Ease of Use**: YAML-based configuration is relatively straightforward.
    * **Marketplace**: Large number of reusable actions available.

### 9. Observability: Google Cloud Monitoring & Logging
* **Requirement**: Use Google Cloud Monitoring for metrics and alerts.
* **Decision**: Utilize Google Cloud Monitoring and Logging.
* **Rationale**:
    * **Native Integration**: Tightly integrated with GCP services, providing many metrics out-of-the-box.
    * **Centralized Platform**: Offers a single place for metrics, logs, dashboards, and alerting.
    * **Customization**: Allows for custom metrics, log-based metrics, and custom dashboards.
    * **Alerting**: Supports various notification channels and flexible alert condition definitions.

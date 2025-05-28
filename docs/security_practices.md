# Security Practices

This document outlines the security practices implemented and recommended for the DogfyDiet Cloud Platform. Security is a multi-layered concern, encompassing infrastructure, network, application, and data.

## Table of Contents

1.  [Guiding Principles](#guiding-principles)
2.  [Identity and Access Management (IAM)](#identity-and-access-management-iam)
3.  [Network Security](#network-security)
4.  [Google Kubernetes Engine (GKE) Security](#google-kubernetes-engine-gke-security)
5.  [Application Security](#application-security)
6.  [Data Security (Firestore & Pub/Sub)](#data-security-firestore--pubsub)
7.  [Secret Management](#secret-management)
8.  [Logging and Monitoring for Security](#logging-and-monitoring-for-security)
9.  [CI/CD Security](#cicd-security)
10. [Incident Response (Placeholder)](#incident-response-placeholder)

---

## 1. Guiding Principles

* **Least Privilege**: Grant only the necessary permissions required for a service or user to perform its function.
* **Defense in Depth**: Implement multiple layers of security controls.
* **Secure by Design**: Integrate security considerations into the architecture and development lifecycle.
* **Automation**: Automate security configurations and checks where possible (e.g., using Terraform, CI/CD security scans).
* **Regular Review**: Periodically review and update security practices.

---

## 2. Identity and Access Management (IAM)

* **Service Accounts**:
    * Dedicated Google Service Accounts (GSAs) are created for different components with specific roles:
        * **GKE Node SA (`dogfydiet-dev-gke-nodes@...`)**: Minimal permissions (Logging Writer, Monitoring Metric Writer/Viewer, Artifact Registry Reader). Nodes use this SA.
        * **Microservice 1 SA (`dogfydiet-dev-microservice-1@...`)**: Permissions for Pub/Sub (Publisher), Logging, Monitoring, Tracing.
        * **Microservice 2 SA (`dogfydiet-dev-microservice-2@...`)**: Permissions for Pub/Sub (Subscriber), Firestore (User), Logging, Monitoring, Tracing.
        * **CI/CD SA (`dogfydiet-github-actions@...`)**: Broader permissions for managing infrastructure and deploying applications (Compute Admin, Container Admin, Storage Admin, etc.). **Recommendation**: For production, this SA's roles should be significantly restricted and potentially split into deployment-specific roles.
    * These are configured in `terraform/modules/iam/main.tf`.
* **Workload Identity**:
    * Enabled on the GKE cluster (`terraform/modules/gke/main.tf`).
    * Kubernetes Service Accounts (KSAs) for Microservice 1 and Microservice 2 are annotated to impersonate their respective GSAs (`k8s/helm-charts/.../values.yaml`). This is the recommended secure way for GKE pods to access GCP services without needing to manage GSA keys.
    * The IAM binding (`roles/iam.workloadIdentityUser`) is configured in `terraform/modules/iam/main.tf`.
* **User Access**: Direct user access to GCP resources should be managed via Google Groups and predefined IAM roles, following the principle of least privilege. Avoid granting `owner` or `editor` roles broadly.
* **Custom IAM Roles**:
    * A custom role `dogfydiet-dev_microservice_minimal` is defined in `terraform/modules/iam/main.tf` for basic logging, monitoring, and tracing, assigned to microservice SAs. This demonstrates fine-grained permission management.

---

## 3. Network Security

* **VPC Network**:
    * A custom VPC (`dogfydiet-dev-vpc`) is used to isolate resources (`terraform/modules/vpc/main.tf`).
    * **Subnets**:
        * Private subnet (`dogfydiet-dev-private-subnet`) for GKE nodes, preventing direct internet exposure.
        * Public subnet (`dogfydiet-dev-public-subnet`) for resources like the NAT Gateway (though the LB is global, its forwarding rules target backends that might eventually route to instances in public subnets if not using NEGs for GKE).
* **Firewall Rules**:
    * Configured in `terraform/modules/vpc/main.tf` and `terraform/environments/dev/main.tf`.
    * `allow-internal`: Allows all traffic within the VPC. **Recommendation**: For production, restrict this to necessary ports/protocols between specific subnets or tags.
    * `allow-http-https`: Allows traffic from `0.0.0.0/0` to the Load Balancer on ports 80/443.
    * `allow-ssh`: Currently allows SSH from `0.0.0.0/0`. **CRITICAL**: For production, this **MUST** be restricted to specific bastion host IPs or internal IPs via IAP.
    * `allow-gke-master`: Allows GKE control plane to communicate with nodes on required ports (443, 10250). Source is the GKE master CIDR.
    * `allow-lb-health-checks-to-gke-nodes`: Allows health checks from GCP Load Balancer IP ranges to GKE nodes on the Microservice 1 health check port (e.g., 3000).
* **Cloud NAT (`dogfydiet-dev-nat`)**:
    * Provides outbound internet connectivity for GKE nodes in the private subnet without assigning them public IPs.
* **HTTP(S) Load Balancer**:
    * **SSL/TLS**: Google-managed SSL certificate is used for `nahueldog.duckdns.org`, terminating SSL at the LB.
    * **HTTPS Redirect**: Configured to redirect HTTP traffic to HTTPS.
    * **Cloud Armor (Placeholder)**: The Load Balancer module includes configuration for Cloud Armor, but it's currently disabled (`enable_cloud_armor = false`). **Recommendation**: Enable Cloud Armor in production for WAF capabilities (SQLi, XSS protection) and DDoS mitigation. Configure appropriate security policies.
* **Private Google Access**: Enabled for the private subnet, allowing GKE nodes to access Google APIs (like Artifact Registry, Pub/Sub) without needing external IPs.

---

## 4. Google Kubernetes Engine (GKE) Security

* **Private Nodes**: GKE nodes are deployed in a private subnet, reducing their attack surface.
* **Public Endpoint with Master Authorized Networks**:
    * The K8s API endpoint is public, but access is restricted by Master Authorized Networks. Currently set to `0.0.0.0/0` in `terraform/modules/gke/main.tf`. **CRITICAL**: For production, this **MUST** be restricted to specific IPs (e.g., CI/CD runners, corporate network).
    * **Recommendation**: Consider enabling the private endpoint for the GKE cluster and accessing it via a bastion host or VPN for enhanced security.
* **Node Service Account**: GKE nodes use a dedicated SA (`dogfydiet-dev-gke-nodes@...`) with minimal permissions.
* **Workload Identity**: As mentioned in IAM, this is the primary mechanism for pod authentication to GCP services.
* **Network Policies**:
    * Defined in Helm charts (`k8s/helm-charts/microservice-1/values.yaml` and `microservice-2/values.yaml`) but may need refinement.
    * They restrict ingress/egress traffic for pods. For example, allowing ingress only from Istio (if used) or specific namespaces, and egress only to necessary services (GCP APIs, DNS).
    * **Recommendation**: Review and tighten Network Policies based on actual communication patterns.
* **Security Contexts (Pods & Containers)**:
    * Helm charts (`values.yaml`) define `podSecurityContext` and `securityContext`:
        * `runAsNonRoot: true`, `runAsUser: 1001`
        * `fsGroup: 1001`
        * `allowPrivilegeEscalation: false`
        * `capabilities: { drop: ["ALL"] }`
        * `readOnlyRootFilesystem: true` (for containers)
    * These settings enhance pod and container security by adhering to the principle of least privilege.
* **Image Security**:
    * Images are stored in Artifact Registry.
    * **Recommendation**: Implement image scanning (e.g., using Google Container Analysis or third-party tools integrated with Artifact Registry) to detect vulnerabilities in Docker images.
* **Node Auto-Upgrades & Auto-Repair**: Enabled in `terraform/modules/gke/main.tf` for node pools to ensure nodes are patched and healthy.
* **Shielded GKE Nodes**: Enabled (`enable_secure_boot = true`, `enable_integrity_monitoring = true`) for enhanced node security.
* **Helm Chart Security**:
    * Values files are used to manage configurations, avoiding hardcoding sensitive data in templates.
    * **Recommendation**: Regularly update Helm chart dependencies and review charts for security best practices.

---

## 5. Application Security

* **Input Validation**:
    * Microservice 1 uses `express-validator` for validating incoming API requests (`POST /api/items`). This is crucial for preventing injection attacks and ensuring data integrity.
* **Output Encoding**: Not explicitly detailed, but frontend frameworks like Vue.js generally handle XSS prevention for dynamic content. Backend services should ensure any data returned is appropriately encoded if it's to be rendered as HTML.
* **Error Handling**:
    * Microservices include structured error responses and logging.
    * Avoid leaking sensitive information (stack traces, internal paths) in error messages to users.
* **Dependencies**:
    * `package.json` files list dependencies.
    * **Recommendation**: Regularly scan dependencies for known vulnerabilities using tools like `npm audit` or Snyk, and update them.
* **Rate Limiting**:
    * Implemented in both microservices using `express-rate-limit` to protect against brute-force and DoS attacks.
* **Security Headers**:
    * `helmet` middleware is used in both microservices to set various HTTP security headers (e.g., X-Content-Type-Options, Strict-Transport-Security, X-Frame-Options, X-XSS-Protection).
* **CORS**:
    * Configured in both microservices to restrict cross-origin requests to allowed origins (defined by `CORS_ORIGIN` env var).
* **Authentication & Authorization (Future)**:
    * Currently, the API is public.
    * **Recommendation**: Implement robust authentication (e.g., OAuth 2.0, OIDC with a provider like Auth0 or Firebase Authentication) and authorization mechanisms for production APIs.

---

## 6. Data Security (Firestore & Pub/Sub)

* **Firestore**:
    * **Security Rules**: The Firestore module (`terraform/modules/firestore/variables.tf`) deploys basic rules allowing read/write if `true`. **CRITICAL**: For production, these **MUST** be replaced with robust rules that enforce authentication and authorization (e.g., `allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;`).
    * **Access Control**: Primarily managed via IAM roles assigned to Microservice 2's GSA (`roles/datastore.user`).
    * **Point-in-Time Recovery (PITR)**: Configured as `false` by default in `terraform/modules/firestore/variables.tf`. **Recommendation**: Enable PITR for production databases.
    * **Delete Protection**: Configured as `false` by default. **Recommendation**: Enable delete protection for production databases.
* **Pub/Sub**:
    * **Access Control**: Managed via IAM roles assigned to GSAs (Publisher for MS1, Subscriber for MS2).
    * **Message Encryption**: Messages are encrypted at rest by Google. For encryption in transit, client libraries use TLS.
    * **Schema Validation (Placeholder)**: The Pub/Sub module has variables for schema configuration but it's not actively used (`create_schema = false`). **Recommendation**: If message structure is critical, define and enforce a schema.

---

## 7. Secret Management

* **Google Secret Manager**:
    * The IAM module (`terraform/modules/iam/main.tf`) provisions Secret Manager secrets to store service account keys (e.g., for Microservice 1 & 2, though Workload Identity is preferred for GKE; primarily for the CI/CD SA key).
    * **Access Control**: Access to secrets is controlled by IAM (`roles/secretmanager.secretAccessor`).
* **Application Configuration**:
    * Non-sensitive configuration is managed via environment variables set in Helm `values.yaml`.
    * **Recommendation**: For sensitive application configuration (e.g., API keys for third-party services), store them in Secret Manager and have applications fetch them at startup using their Workload Identity. Avoid putting secrets directly in `values.yaml` or Docker images. The `GCP_SA_KEY` for GitHub Actions is an example of a secret that should be stored in GitHub Secrets, not in code.

---

## 8. Logging and Monitoring for Security

* **Cloud Logging**: Centralized logging for all GCP services and applications.
    * GKE system and application logs are collected.
    * Microservices use Winston for structured logging, which is then ingested by Cloud Logging.
* **Cloud Monitoring**:
    * Metrics from GCP services and GKE are collected.
    * The Monitoring module (`terraform/modules/monitoring/main.tf`) sets up:
        * Alert policies for GKE CPU/Memory usage, error log counts.
        * A basic dashboard.
    * **Recommendation**:
        * Create specific alert policies for security-related events (e.g., IAM policy changes, firewall modifications, high rate of 401/403 errors, anomalous GSA activity).
        * Use VPC Flow Logs and Firewall Rules Logging for network traffic analysis.
        * Integrate with Security Command Center for centralized threat detection.

---

## 9. CI/CD Security

* **GitHub Actions**:
    * The `build-deploy.yml` and `minimal-terraform-ci.yml` workflows define build, test, and deployment steps.
    * **Service Account Key (`GCP_SA_KEY`)**: Stored as a GitHub Secret. This key has broad permissions. **Recommendation**:
        * Use Workload Identity Federation for GitHub Actions to allow workflows to impersonate a GCP service account without needing long-lived keys.
        * If keys are used, ensure they are regularly rotated and have the minimum necessary permissions for the CI/CD tasks.
    * **Dependency Scanning**: **Recommendation**: Add steps to scan application dependencies (e.g., `npm audit`) and Docker images for vulnerabilities within the CI pipeline.
    * **Static Analysis Security Testing (SAST)**: **Recommendation**: Integrate SAST tools to analyze code for security flaws.
    * **Branch Protection Rules**: Enforce PR reviews, status checks passing before merging to `main`.
    * **Secret Scanning**: Enable secret scanning in the GitHub repository settings.

---

## 10. Incident Response (Placeholder)

* **Recommendation**: Develop an incident response plan that outlines:
    * Roles and responsibilities.
    * Communication channels.
    * Steps for identifying, containing, eradicating, and recovering from security incidents.
    * Post-incident review process.

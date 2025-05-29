# CI/CD Pipeline (`docs/ci_cd.md`)

This document details the Continuous Integration/Continuous Deployment (CI/CD) pipelines implemented for the DogfyDiet Cloud Platform using GitHub Actions.

## Table of Contents

1.  [Overview](#overview)
2.  [Tools Used](#tools-used)
3.  [Workflows](#workflows)
    * [Infrastructure CI/CD (`minimal-terraform-ci.yml`)](#infrastructure-cicd-minimal-terraform-ciyml)
    * [Application Build & Deploy (`build-deploy.yml`)](#application-build--deploy-build-deployyml)
    * [Release Management (`release.yml`)](#release-management-releaseyml)
4.  [Branching Strategy](#branching-strategy)
5.  [Secrets Management](#secrets-management-for-cicd)
6.  [Security Considerations for CI/CD](#security-considerations-for-cicd)
7.  [Future Improvements](#future-improvements)

---

## 1. Overview

The CI/CD pipelines automate the testing, building, and deployment of both the infrastructure (Terraform) and the applications (Frontend, Microservice 1, Microservice 2). This ensures consistency, reduces manual error, and enables faster iteration.

Key goals of the CI/CD setup:
* **Infrastructure as Code Automation**: Validate and apply Terraform changes automatically.
* **Application Builds**: Build Docker images for backend microservices and static assets for the frontend.
* **Automated Deployments**: Deploy applications to GKE and GCS.
* **Release Management**: Streamline the process of creating tagged releases.

---

## 2. Tools Used

* **GitHub Actions**: The primary platform for orchestrating CI/CD workflows. Workflows are defined in YAML files located in the `.github/workflows/` directory.
* **Terraform**: Used for infrastructure provisioning.
* **Docker**: Used for containerizing backend microservices.
* **Helm**: Used for packaging and deploying applications to GKE.
* **Google Cloud SDK (`gcloud`)**: Used for interacting with GCP services (Artifact Registry, GKE, GCS).
* **Node.js/npm**: Used for building the frontend application.

---

## 3. Workflows

### a. Infrastructure CI/CD (`minimal-terraform-ci.yml`)

* **Purpose**: Manages the lifecycle of the GCP infrastructure defined by Terraform.
* **Trigger**:
    * Push to the `main` branch on paths `terraform/**` or `.github/workflows/minimal-terraform-ci.yml`.
    * Pull request to the `main` branch on paths `terraform/**` or `.github/workflows/minimal-terraform-ci.yml`.
* **Key Jobs & Steps**:
    1.  **Checkout**: Checks out the repository code.
    2.  **Setup Terraform**: Initializes the specified Terraform version.
    3.  **Terraform Format Check (`terraform fmt -check`)**: Ensures code formatting consistency.
    4.  **Initialize Terraform (Local Validation)**: Runs `terraform init -backend=false` for local validation steps.
    5.  **Validate Terraform (`terraform validate`)**: Checks the syntax and configuration of Terraform files.
    6.  **Authenticate to Google Cloud**: Uses `google-github-actions/auth` with `secrets.GCP_SA_KEY` for plan/apply steps.
    7.  **Initialize Terraform (Full Backend)**: Runs `terraform init` with the GCS backend for plan/apply.
    8.  **Terraform Plan (Pull Request)**:
        * Runs `terraform plan -detailed-exitcode -out=tfplan`.
        * Comments the plan status (changes, no changes, or errors) on the pull request.
        * Uploads the plan file (`tfplan`) and output text as an artifact.
    9.  **Terraform Plan (Main Branch before Apply)**: Runs `terraform plan -out=tfplan` if on `main` branch.
    10. **Terraform Apply (Main Branch)**:
        * Runs `terraform apply -auto-approve tfplan` automatically on pushes to `main` if all previous steps (format, validate, plan) succeed.
    11. **Terraform Output (Main Branch)**: Saves `terraform output` to a file and uploads it as an artifact.
* **Secrets Used**:
    * `secrets.GCP_SA_KEY`: Service Account key for authenticating to GCP.
    * `secrets.NOTIFICATION_EMAIL`: Used as `TF_VAR_notification_email` for Terraform (e.g., for monitoring alerts).
* **Environment**: `dev` (GitHub Actions environment).

### b. Application Build & Deploy (`build-deploy.yml`)

* **Purpose**: Builds and deploys the frontend and backend microservices.
* **Trigger**:
    * Push to the `main` branch on paths `applications/**`, `k8s/**`, or `.github/workflows/build-deploy.yml`.
    * `workflow_dispatch`: Allows manual triggering with options to deploy frontend and/or microservices.
* **Key Jobs & Steps**:
    * **`build-microservice-1` & `build-microservice-2` Jobs**:
        1.  Checkout code.
        2.  Authenticate to GCP.
        3.  Set up `gcloud` and configure Docker credential helper.
        4.  Build Docker images tagged with `github.sha` and `latest`.
        5.  Push images to Google Artifact Registry (`us-central1-docker.pkg.dev/nahuelgabe-test/dogfydiet-dev-docker-repo/...`).
    * **`deploy-frontend` Job**:
        1.  Checkout code.
        2.  Setup Node.js.
        3.  Install frontend dependencies (`npm ci`).
        4.  Build frontend (`npm run build`), using `secrets.API_URL` for `VUE_APP_API_URL`.
        5.  Authenticate to GCP.
        6.  Set up `gcloud`.
        7.  Deploy static files from `dist/` to the GCS bucket specified by `secrets.FRONTEND_BUCKET_NAME` using `gsutil rsync`.
        8.  Sets `Cache-Control` headers for various file types in GCS.
    * **`deploy-microservices` Job** (depends on successful build jobs):
        1.  Checkout code.
        2.  Authenticate to GCP.
        3.  Set up `gcloud` and install `gke-gcloud-auth-plugin`.
        4.  Get GKE cluster credentials.
        5.  Setup Helm.
        6.  Deploy/Upgrade Microservice 1 and Microservice 2 using `helm upgrade --install`.
            * Sets image repository and tag (`github.sha`).
            * Configures service account annotations for Workload Identity.
        7.  Verify deployments (`kubectl get pods`, `kubectl get services`).
        8.  Generates a deployment summary.
* **Secrets Used**:
    * `secrets.GCP_SA_KEY`: For GCP authentication.
    * `secrets.API_URL`: Base URL for the backend API, used by the frontend build.
    * `secrets.FRONTEND_BUCKET_NAME`: Name of the GCS bucket for frontend hosting.
* **Environment**: `dev`.

### c. Release Management (`release.yml`)

* **Purpose**: Automates the creation of GitHub releases when a new version tag is pushed.
* **Trigger**: Push of tags matching the pattern `v*` (e.g., `v1.0.0`, `v1.1.0-beta`).
* **Key Jobs & Steps**:
    * **`generate-changelog` Job**:
        1.  Checkout code (with full fetch depth).
        2.  Generates a changelog based on commit messages between the current and previous tag.
        3.  Categorizes changes (Infrastructure, Application, DevOps, Other).
        4.  Uploads the changelog as an artifact.
    * **`build-and-tag-images` Job** (matrix strategy for `microservice-1`, `microservice-2`):
        1.  Checkout code.
        2.  Extracts version from the Git tag.
        3.  Authenticates to GCP.
        4.  Sets up `gcloud` and Docker credential helper.
        5.  Builds Docker images for each microservice, tagging them with the extracted version (e.g., `1.0.0`) and `stable`.
        6.  Pushes these images to Artifact Registry.
    * **`create-release` Job** (depends on `generate-changelog` and `build-and-tag-images`):
        1.  Checkout code.
        2.  Downloads the changelog artifact.
        3.  Creates a GitHub Release using the Git tag name, with the changelog content as the release body.
        4.  Generates a release summary.
* **Secrets Used**:
    * `secrets.GCP_SA_KEY`: For pushing images to Artifact Registry.
    * `secrets.GITHUB_TOKEN`: Automatically provided by GitHub Actions for creating the release.
* **Environment**: `dev`.

---

## 4. Branching Strategy (Implied)

* **`main`**: The primary branch representing the latest stable state of the `dev` environment. Pushes to `main` trigger deployments.
* **Feature Branches**: Developers should create branches from `main` for new features or fixes (e.g., `feature/new-api-endpoint`, `fix/login-bug`).
* **Pull Requests (PRs)**: Changes are merged into `main` via PRs, which trigger Terraform plan checks.
* **Tags (`v*`)**: Used for versioning and triggering official releases.

---

## 5. Secrets Management for CI/CD

* **GitHub Secrets**: All sensitive information required by the CI/CD pipelines is stored as encrypted secrets in the GitHub repository settings.
    * `GCP_SA_KEY`: A base64 encoded JSON key for the `dogfydiet-github-actions` service account. This SA is created by `scripts/bootstrap.sh` with broad permissions.
    * `API_URL`: The base URL of the deployed API (Microservice 1), used by the frontend build process.
    * `FRONTEND_BUCKET_NAME`: The name of the GCS bucket where the frontend is hosted.
    * `NOTIFICATION_EMAIL`: Email address for Terraform notifications (e.g., monitoring alerts).
* **Access to Secrets**: Secrets are exposed to workflows as environment variables or inputs to actions.

---

## 6. Security Considerations for CI/CD

* **Service Account Permissions**: The `GCP_SA_KEY` currently corresponds to a service account with extensive permissions. For production, this is a significant risk.
    * **Recommendation**:
        * Use **Workload Identity Federation for GitHub Actions**. This allows GitHub Actions workflows to impersonate a GCP service account without needing to store long-lived SA keys as GitHub secrets.
        * If SA keys must be used, ensure they are regularly rotated and the associated SA has the absolute minimum permissions required for CI/CD tasks (e.g., separate SAs for Terraform apply vs. image push vs. GKE deploy).
* **Branch Protection Rules**:
    * **Recommendation**: Configure branch protection rules for `main` to require PR reviews, passing status checks (including CI checks from these workflows) before merging.
* **Secret Scanning**:
    * **Recommendation**: Enable GitHub's secret scanning feature to detect accidental commitment of secrets.
* **Dependency Vulnerability Scanning**:
    * **Recommendation**: Add steps to workflows to scan application dependencies (e.g., `npm audit`) and Docker images (e.g., using `gcloud artifacts docker images scan` or Trivy) for known vulnerabilities.
* **Static Analysis Security Testing (SAST)**:
    * **Recommendation**: Integrate SAST tools (e.g., SonarCloud, CodeQL) to analyze code for potential security flaws during the CI process.
* **Terraform Plan Review**: The `minimal-terraform-ci.yml` workflow includes commenting the plan on PRs, which is good practice for reviewing infrastructure changes.

---

## 7. Future Improvements

* **Comprehensive Testing**: Integrate more extensive automated testing stages:
    * Unit tests for frontend and backend.
    * Integration tests.
    * End-to-end (E2E) tests.
* **Environment Promotion**: Develop distinct CI/CD pipelines or stages for deploying to staging and production environments, with appropriate manual approvals or promotion strategies.
* **Advanced Deployment Strategies**: Implement canary releases or blue/green deployments for GKE applications to reduce deployment risk.
* **Infrastructure Testing**: Incorporate tools like Terratest for testing Terraform modules.
* **GitOps**: Consider adopting GitOps principles for managing GKE application deployments (e.g., using ArgoCD or FluxCD) for a more declarative and auditable deployment process.
* **Pipeline Optimization**: Improve pipeline speed and efficiency (e.g., caching, parallelization).
* **Security Enhancements**: Implement the security recommendations listed above (WIF, vulnerability scanning, SAST).



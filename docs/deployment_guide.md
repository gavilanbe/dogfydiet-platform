# Deployment Guide

This guide provides detailed steps to deploy the DogfyDiet Cloud Platform infrastructure and applications on Google Cloud Platform.

## Prerequisites

Before you begin, ensure you have the following tools installed and configured:

* **Google Cloud SDK (`gcloud`)**: [Installation Guide](https://cloud.google.com/sdk/docs/install)
    * Authenticated: Run `gcloud auth login` and `gcloud auth application-default login`.
    * Project Set: Run `gcloud config set project YOUR_PROJECT_ID`.
* **Terraform**: Version >= 1.5.0 recommended. [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
* **`kubectl`**: Kubernetes command-line tool. [Installation Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl-gcloud/) (can be installed via `gcloud components install kubectl`).
* **Helm**: Kubernetes package manager. [Installation Guide](https://helm.sh/docs/intro/install/)
* **Docker**: Containerization platform. [Installation Guide](https://docs.docker.com/engine/install/)
* **Node.js & npm/yarn**: For local application development and building the frontend. [Node.js Website](https://nodejs.org/)
* **Git**: For cloning the repository.

## 1. Project Configuration & Setup

### a. Clone Repository
```bash
git clone [https://github.com/your-username/dogfydiet-platform.git](https://github.com/your-username/dogfydiet-platform.git)
cd dogfydiet-platform
```

### b. Terraform Backend Configuration
Terraform uses a Google Cloud Storage (GCS) bucket for its remote state backend.

* **Option 1: Use Bootstrap Script (Recommended)**
    The `scripts/bootstrap.sh` script can create this bucket for you. \[cite: 354-365\]
    ```bash
    chmod +x scripts/bootstrap.sh
    ./scripts/bootstrap.sh
    ```
    This script will:
    1.  Prompt for your GCP Project ID (defaults to `nahuelgabe-test`).
    2.  Create a GCS bucket named `YOUR_PROJECT_ID-terraform-state` (e.g., `nahuelgabe-test-terraform-state` if it uses the default project ID from the script) if it doesn't exist. The Terraform configuration in `terraform/environments/dev/main.tf` specifies `nahuelgabe-test-terraform-state`.
    3.  Update or create `terraform/environments/dev/backend.tf` with this bucket name (the script intends to create `terraform/environments/dev/backend.tf`, ensure this aligns with `main.tf`'s backend block or consolidate).
    4.  Create a service account for CI/CD (`dogfydiet-github-actions`) and download its key as `sa-key.json` in the root directory.
        * **Security Note**: The bootstrap script grants broad permissions to the CI/CD service account. For production, these roles should be reviewed and minimized.
        * Store the `sa-key.json` securely and use its base64 encoded content for the `GCP_SA_KEY` GitHub secret if setting up CI/CD.

* **Option 2: Manual Configuration**
    1.  Create a GCS bucket manually (ensure it matches the name in `terraform/environments/dev/main.tf`'s backend block, e.g., `nahuelgabe-test-terraform-state`):
        ```bash
        gsutil mb -p YOUR_PROJECT_ID -l YOUR_REGION gs://nahuelgabe-test-terraform-state
        gsutil versioning set on gs://nahuelgabe-test-terraform-state
        ```
    2.  Ensure the `terraform/environments/dev/main.tf` backend block is correctly configured:
        ```terraform
        terraform {
          # ...
          backend "gcs" {
            bucket = "nahuelgabe-test-terraform-state" // Verify this matches your bucket
            prefix = "dogfydiet-platform/dev"
          }
        }
        ```

### c. Terraform Variables
Review and update variables in `terraform/environments/dev/terraform.tfvars`. At a minimum, ensure `project_id` is correct (e.g., `nahuelgabe-test`).
The `notification_email` variable should also be set to your desired email for monitoring alerts (e.g., `nahuelgavilanbe@gmail.com`).

## 2. Infrastructure Provisioning with Terraform

Navigate to the development environment directory:
```bash
cd terraform/environments/dev
```

Initialize Terraform (downloads providers and configures the backend):
```bash
terraform init
```

Review the execution plan (shows what resources Terraform will create, modify, or destroy):
```bash
terraform plan
```

Apply the infrastructure changes:
```bash
terraform apply
```
Confirm by typing `yes` when prompted. This process will take several minutes as it provisions all GCP resources. Key outputs like the Load Balancer IP and GKE cluster name will be displayed upon completion. \[cite: 9-15\]

## 3. Configure `kubectl` for GKE Cluster

Once Terraform completes, it will output a command to configure `kubectl` (look for the `kubectl_config` output). Copy and run this command. It will look similar to:
```bash
# Example from Terraform output
gcloud container clusters get-credentials dogfydiet-dev-cluster --region us-central1 --project nahuelgabe-test
```
*(The exact cluster name, region, and project ID will be based on your Terraform configuration.)*

Verify `kubectl` access:
```bash
kubectl get nodes
```

## 4. Application Deployment

### a. Build and Push Docker Images
The backend microservices need to be containerized and pushed to the Google Artifact Registry repository created by Terraform. The repository URL is an output from `terraform apply` (e.g., `docker_repository_url`).

**For Microservice 1:**
```bash
cd applications/microservice-1

# Construct the image name. Example:
# AR_REPO_URL=$(cd ../../terraform/environments/dev && terraform output -raw docker_repository_url)
# IMAGE_NAME_MS1="${AR_REPO_URL}/microservice-1:latest"
# Based on provided outputs and IAM module, it would be similar to:
# us-central1-docker.pkg.dev/nahuelgabe-test/dogfydiet-dev-docker-repo/microservice-1:latest

# Replace with your actual image name from Terraform output
IMAGE_NAME_MS1="<YOUR_ARTIFACT_REGISTRY_URL>/microservice-1:latest" # e.g., us-central1-docker.pkg.dev/nahuelgabe-test/dogfydiet-dev-docker-repo/microservice-1:latest

docker build -t $IMAGE_NAME_MS1 .

# Authenticate Docker with Artifact Registry (if needed, usually once per region)
gcloud auth configure-docker <YOUR_ARTIFACT_REGISTRY_REGION>-docker.pkg.dev # e.g., us-central1-docker.pkg.dev

docker push $IMAGE_NAME_MS1
```

**For Microservice 2:**
```bash
cd applications/microservice-2

# Replace with your actual image name from Terraform output
IMAGE_NAME_MS2="<YOUR_ARTIFACT_REGISTRY_URL>/microservice-2:latest" # e.g., us-central1-docker.pkg.dev/nahuelgabe-test/dogfydiet-dev-docker-repo/microservice-2:latest

docker build -t $IMAGE_NAME_MS2 .
docker push $IMAGE_NAME_MS2
```
*(Ensure you replace `<YOUR_ARTIFACT_REGISTRY_URL>` with the actual URL from Terraform output `docker_repository_url` and `<YOUR_ARTIFACT_REGISTRY_REGION>` with the region like `us-central1`.)*

### b. Deploy Backend Microservices using Helm
Update the `values.yaml` file for each Helm chart (`k8s/helm-charts/microservice-1/values.yaml` \[cite: 320-325\] and `k8s/helm-charts/microservice-2/values.yaml` \[cite: 267-271\]) with the correct:
* `image.repository`: The full path to your image in Artifact Registry (e.g., `us-central1-docker.pkg.dev/nahuelgabe-test/dogfydiet-dev-docker-repo/microservice-1`).
* `image.tag`: The tag you used (e.g., `latest`).
* `serviceAccount.annotations."iam.gke.io/gcp-service-account"`: The GCP service account email for the respective microservice. These are outputs from Terraform (e.g., `module.iam.microservice_1_service_account`).
    * Microservice 1 SA (example from `values.yaml`): `dogfydiet-dev-microservice-1@nahuelgabe-test.iam.gserviceaccount.com`
    * Microservice 2 SA (example from `values.yaml`): `dogfydiet-dev-microservice-2@nahuelgabe-test.iam.gserviceaccount.com`
* `env.GOOGLE_CLOUD_PROJECT`: Your GCP Project ID (e.g., `nahuelgabe-test`).
* `env.PUBSUB_TOPIC` (for MS1): e.g., `dogfydiet-dev-items-topic` (matches Terraform output `pubsub_topic_name`).
* `env.PUBSUB_SUBSCRIPTION` (for MS2): e.g., `dogfydiet-dev-items-subscription` (matches Terraform output `pubsub_subscription_name`).
* `env.CORS_ORIGIN` (for MS1): Update with the frontend URL if it's not `https://nahueldog.duckdns.org` or `http://localhost:8080`. The load balancer is configured for `nahueldog.duckdns.org`.

**Deploy Microservice 1:**
```bash
cd k8s/helm-charts/microservice-1
helm install microservice-1 . -n default # Or your desired namespace
```

**Deploy Microservice 2:**
```bash
cd ../microservice-2 # Assuming you are in k8s/helm-charts
helm install microservice-2 . -n default # Or your desired namespace
```

Verify deployments:
```bash
kubectl get deployments -n default
kubectl get pods -n default
```

### c. Deploy Frontend Application
The frontend is a Vue.js application. \[cite: 367, 370-401\]

**1. Set API URL Environment Variable (Important for Frontend Build):**
The frontend needs to know the URL of Microservice 1. The Load Balancer IP is an output from Terraform (`load_balancer_ip` or `frontend_url`).
You need to set this for the frontend build process. Create a `.env.local` file in `applications/frontend/` (this file is typically gitignored):
```
VUE_APP_API_URL=http://<LOAD_BALANCER_IP>/api
```
Replace `<LOAD_BALANCER_IP>` with the actual IP address from the Terraform output `module.loadbalancer.load_balancer_ip`.

**2. Build the Frontend:**
```bash
cd applications/frontend
npm install # If you haven't already
npm run build
```
This creates a `dist/` directory with the static assets.

**3. Upload to GCS:**
The GCS bucket name for the frontend is an output from Terraform (`frontend_bucket_name`).
```bash
# Example from Terraform output:
# FRONTEND_BUCKET_NAME_OUTPUT=$(cd ../../terraform/environments/dev && terraform output -raw frontend_bucket_name)
# gsutil -m rsync -r -d dist/ gs://${FRONTEND_BUCKET_NAME_OUTPUT}/

# The Terraform output setup_instructions suggests:
# Update GitHub secret FRONTEND_BUCKET_NAME with: ${module.storage.frontend_bucket_name}
# So, obtain the bucket name from the output:
# frontend_bucket_name = "dogfydiet-dev-frontend-xxxxxxxx" (example)

gsutil -m rsync -r -d dist/ gs://<your-frontend-bucket-name>/ # Replace <your-frontend-bucket-name>
```
The `storage` Terraform module configures the bucket for public read access to objects.

## 5. Accessing the Application

* **Frontend URL**: The application should be accessible via the Load Balancer's IP address. This is provided as a Terraform output `frontend_url` (e.g., `http://<LOAD_BALANCER_IP>`). If you configured DNS for `nahueldog.duckdns.org` to point to this IP, then `https://nahueldog.duckdns.org` should also work.
* **Backend API (Microservice 1)**: Accessible via `http://<LOAD_BALANCER_IP>/api/items` (as per path rule in LB module and Microservice 1 routes \[cite: 474-481\]).

## 6. Updating and Redeploying

* **Infrastructure Changes**: Modify Terraform code, then run `terraform plan` and `terraform apply`.
* **Application Changes**:
    1.  Rebuild Docker image(s) with a new tag (or `latest`).
    2.  Push to Artifact Registry.
    3.  Update `image.tag` in the relevant Helm `values.yaml`.
    4.  Run `helm upgrade <release-name> . -n <namespace>` for the microservice.
    5.  For frontend, rebuild (`npm run build`) and re-sync to GCS.

Automating these update steps is the role of a CI/CD pipeline.

## 7. Destroying Infrastructure (Use with Extreme Caution)

To remove all deployed resources:
```bash
cd terraform/environments/dev
terraform destroy
```
Confirm by typing `yes` when prompted. This will delete everything managed by Terraform in this configuration. \[cite: 259-261\]

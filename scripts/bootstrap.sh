#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-nahuelgabe-test}"
REGION="${GCP_REGION:-us-central1}"
TERRAFORM_STATE_BUCKET="${TERRAFORM_STATE_BUCKET:-${PROJECT_ID}-terraform-state}"

echo -e "${GREEN}🚀 DogfyDiet Platform - Bootstrap Setup${NC}"
echo "================================================"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI is not installed. Please install it first.${NC}"
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed. Please install it first.${NC}"
    echo "Visit: https://learn.hashicorp.com/tutorials/terraform/install-cli"
    exit 1
fi

# Check gcloud authentication
echo -e "\n${YELLOW}Checking GCP authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}❌ Not authenticated with GCP. Running 'gcloud auth login'...${NC}"
    gcloud auth login
fi

# Set project
echo -e "\n${YELLOW}Setting GCP project to: ${PROJECT_ID}${NC}"
gcloud config set project ${PROJECT_ID}

# Create terraform state bucket if it doesn't exist
echo -e "\n${YELLOW}Creating Terraform state bucket...${NC}"
if ! gsutil ls -b gs://${TERRAFORM_STATE_BUCKET} &> /dev/null; then
    echo "Creating bucket: gs://${TERRAFORM_STATE_BUCKET}"
    gsutil mb -p ${PROJECT_ID} -l ${REGION} gs://${TERRAFORM_STATE_BUCKET}
    
    # Enable versioning
    gsutil versioning set on gs://${TERRAFORM_STATE_BUCKET}
    
    # Set lifecycle rule to delete old versions after 30 days
    cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 30,
          "isLive": false
        }
      }
    ]
  }
}
EOF
    gsutil lifecycle set /tmp/lifecycle.json gs://${TERRAFORM_STATE_BUCKET}
    rm /tmp/lifecycle.json
    
    echo -e "${GREEN}✅ Terraform state bucket created successfully${NC}"
else
    echo -e "${GREEN}✅ Terraform state bucket already exists${NC}"
fi

# Create a service account for GitHub Actions CI/CD
echo -e "\n${YELLOW}Creating CI/CD service account...${NC}"
SA_NAME="dogfydiet-github-actions"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe ${SA_EMAIL} --project=${PROJECT_ID} &> /dev/null; then
    echo "Creating service account: ${SA_NAME}"
    gcloud iam service-accounts create ${SA_NAME} \
        --display-name="DogfyDiet GitHub Actions CI/CD" \
        --description="Service account for GitHub Actions CI/CD pipeline" \
        --project=${PROJECT_ID}
    
    # Grant necessary roles
    echo "Granting IAM roles..."
    roles=(
        "roles/compute.admin"
        "roles/container.admin"
        "roles/storage.admin"
        "roles/iam.serviceAccountUser"
        "roles/artifactregistry.admin"
        "roles/secretmanager.admin"
        "roles/pubsub.admin"
        "roles/datastore.owner"
        "roles/monitoring.admin"
        "roles/logging.admin"
    )
    
    for role in "${roles[@]}"; do
        echo "  - ${role}"
        gcloud projects add-iam-policy-binding ${PROJECT_ID} \
            --member="serviceAccount:${SA_EMAIL}" \
            --role="${role}" \
            --quiet
    done
    
    echo -e "${GREEN}✅ Service account created and configured${NC}"
else
    echo -e "${GREEN}✅ Service account already exists${NC}"
fi

# Create and download service account key
echo -e "\n${YELLOW}Creating service account key...${NC}"
KEY_FILE="./sa-key.json"
if [ ! -f "${KEY_FILE}" ]; then
    gcloud iam service-accounts keys create ${KEY_FILE} \
        --iam-account=${SA_EMAIL} \
        --project=${PROJECT_ID}
    
    echo -e "${GREEN}✅ Service account key created: ${KEY_FILE}${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: This key will be used for GitHub Actions. Keep it secure!${NC}"
else
    echo -e "${YELLOW}⚠️  Service account key already exists: ${KEY_FILE}${NC}"
fi

# Update terraform backend configuration
echo -e "\n${YELLOW}Updating Terraform backend configuration...${NC}"
BACKEND_FILE="terraform/environments/dev/backend.tf"
if [ ! -f "${BACKEND_FILE}" ]; then
    cat > ${BACKEND_FILE} <<EOF
terraform {
  backend "gcs" {
    bucket = "${TERRAFORM_STATE_BUCKET}"
    prefix = "dogfydiet-platform/dev"
  }
}
EOF
    echo -e "${GREEN}✅ Created backend configuration: ${BACKEND_FILE}${NC}"
else
    echo -e "${YELLOW}⚠️  Backend configuration already exists. Please verify bucket name is correct.${NC}"
fi

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Bootstrap setup completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nNext steps:"
echo -e "1. Configure GitHub secrets (see docs/github-secrets-setup.md)"
echo -e "2. Base64 encode the service account key:"
echo -e "   ${YELLOW}cat ${KEY_FILE} | base64 -w 0${NC}"
echo -e "3. Add the encoded key as GitHub secret: GCP_SA_KEY"
echo -e "4. Initialize Terraform:"
echo -e "   ${YELLOW}cd terraform/environments/dev && terraform init${NC}"
echo -e "5. Review and apply Terraform:"
echo -e "   ${YELLOW}terraform plan && terraform apply${NC}"
echo -e "\n${RED}⚠️  Remember to keep ${KEY_FILE} secure and delete it after adding to GitHub secrets!${NC}"
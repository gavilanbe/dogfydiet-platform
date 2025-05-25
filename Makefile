# DogfyDiet Platform Makefile

.PHONY: help bootstrap init plan apply destroy clean lint validate

# Default target
help:
	@echo "DogfyDiet Platform - Available Commands:"
	@echo "  make bootstrap    - Run initial setup (create state bucket, service accounts)"
	@echo "  make init        - Initialize Terraform"
	@echo "  make plan        - Run Terraform plan"
	@echo "  make apply       - Apply Terraform changes"
	@echo "  make destroy     - Destroy all infrastructure (careful!)"
	@echo "  make clean       - Clean local files"
	@echo "  make lint        - Lint Terraform files"
	@echo "  make validate    - Validate Terraform configuration"

# Run bootstrap setup
bootstrap:
	@echo "Running bootstrap setup..."
	@chmod +x scripts/bootstrap.sh
	@./scripts/bootstrap.sh

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	@cd terraform/environments/dev && terraform init

# Run Terraform plan
plan:
	@echo "Running Terraform plan..."
	@cd terraform/environments/dev && terraform plan

# Apply Terraform changes
apply:
	@echo "Applying Terraform changes..."
	@cd terraform/environments/dev && terraform apply

# Destroy infrastructure
destroy:
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		cd terraform/environments/dev && terraform destroy; \
	else \
		echo "Destroy cancelled."; \
	fi

# Clean local files
clean:
	@echo "Cleaning local files..."
	@rm -f sa-key.json sa-key-encoded.txt
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.tfplan" -exec rm -f {} + 2>/dev/null || true
	@find . -type f -name "*.tfstate*" -exec rm -f {} + 2>/dev/null || true
	@echo "Clean complete!"

# Lint Terraform files
lint:
	@echo "Linting Terraform files..."
	@terraform fmt -recursive terraform/

# Validate Terraform configuration
validate:
	@echo "Validating Terraform configuration..."
	@cd terraform/environments/dev && terraform validate

# Quick setup (bootstrap + init + plan)
quickstart: bootstrap init plan
	@echo "Quickstart complete! Review the plan and run 'make apply' when ready."
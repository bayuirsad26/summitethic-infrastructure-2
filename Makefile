# SummitEthic Infrastructure Makefile
# Automates common tasks for infrastructure management

# Variables
ENV ?= development
ANSIBLE_DIR = ansible
TERRAFORM_DIR = terraform
VAULT_PASSWORD_FILE ?= .vault_pass
ANSIBLE_PLAYBOOK = ansible-playbook -i $(ANSIBLE_DIR)/inventories/$(ENV)/inventory.yml
TERRAFORM = cd $(TERRAFORM_DIR)/environments/$(ENV) && terraform

# Help target
.PHONY: help
help:
	@echo "SummitEthic Infrastructure Make Commands"
	@echo "------------------------------------------"
	@echo "Usage: make [target] [ENV=environment]"
	@echo ""
	@echo "Available targets:"
	@echo "  help                Show this help message"
	@echo "  install             Install dependencies"
	@echo "  lint                Run linting checks"
	@echo "  security-check      Run security checks"
	@echo "  ethical-check       Run ethical code checks"
	@echo "  deploy              Deploy infrastructure (ENV=development|staging|production)"
	@echo "  deploy-core         Deploy core infrastructure only"
	@echo "  deploy-services     Deploy services only"
	@echo "  deploy-monitoring   Deploy monitoring only"
	@echo "  deploy-platform     Deploy platform only"
	@echo "  provision           Provision cloud infrastructure with Terraform"
	@echo "  tf-plan             Run Terraform plan"
	@echo "  tf-apply            Run Terraform apply"
	@echo "  tf-destroy          Run Terraform destroy (USE WITH CAUTION)"
	@echo "  backup              Run backup tasks"
	@echo "  security-audit      Run security audit"
	@echo "  ethical-audit       Run ethical audit"
	@echo "  docs                Generate documentation"
	@echo "  clean               Clean up temporary files"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy ENV=staging"
	@echo "  make security-audit ENV=production"
	@echo ""

# Install dependencies
.PHONY: install
install:
	@echo "Installing dependencies..."
	pip install -r requirements.txt
	ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml
	pre-commit install

# Linting
.PHONY: lint
lint:
	@echo "Running linting checks..."
	ansible-lint $(ANSIBLE_DIR)
	yamllint -c .yamllint $(ANSIBLE_DIR)
	cd $(TERRAFORM_DIR) && terraform fmt -check -recursive
	flake8 scripts/

# Security check
.PHONY: security-check
security-check:
	@echo "Running security checks..."
	bandit -r $(ANSIBLE_DIR) -f txt
	cd $(TERRAFORM_DIR) && tfsec .
	gitleaks detect --source . --verbose

# Ethical check
.PHONY: ethical-check
ethical-check:
	@echo "Running ethical code checks..."
	python scripts/ethical_code_check.py --all

# Deploy infrastructure
.PHONY: deploy
deploy:
	@echo "Deploying infrastructure to $(ENV)..."
	$(ANSIBLE_PLAYBOOK) $(ANSIBLE_DIR)/playbooks/site.yml --vault-password-file $(VAULT_PASSWORD_FILE)

# Deploy core infrastructure
.PHONY: deploy-core
deploy-core:
	@echo "Deploying core infrastructure to $(ENV)..."
	$(ANSIBLE_PLAYBOOK) $(ANSIBLE_DIR)/playbooks/core.yml --vault-password-file $(VAULT_PASSWORD_FILE)

# Deploy services
.PHONY: deploy-services
deploy-services:
	@echo "Deploying services to $(ENV)..."
	$(ANSIBLE_PLAYBOOK) $(ANSIBLE_DIR)/playbooks/services.yml --vault-password-file $(VAULT_PASSWORD_FILE)

# Deploy monitoring
.PHONY: deploy-monitoring
deploy-monitoring:
	@echo "Deploying monitoring to $(ENV)..."
	$(ANSIBLE_PLAYBOOK) $(ANSIBLE_DIR)/playbooks/monitoring.yml --vault-password-file $(VAULT_PASSWORD_FILE)

# Deploy platform
.PHONY: deploy-platform
deploy-platform:
	@echo "Deploying platform to $(ENV)..."
	$(ANSIBLE_PLAYBOOK) $(ANSIBLE_DIR)/playbooks/platform.yml --vault-password-file $(VAULT_PASSWORD_FILE)

# Provision infrastructure
.PHONY: provision
provision: tf-plan tf-apply

# Terraform plan
.PHONY: tf-plan
tf-plan:
	@echo "Running Terraform plan for $(ENV)..."
	$(TERRAFORM) init
	$(TERRAFORM) plan -out=tfplan

# Terraform apply
.PHONY: tf-apply
tf-apply:
	@echo "Running Terraform apply for $(ENV)..."
	$(TERRAFORM) apply tfplan

# Terraform destroy
.PHONY: tf-destroy
tf-destroy:
	@echo "WARNING: This will destroy all resources in $(ENV)!"
	@echo "Are you sure? Type 'yes' to confirm:"
	@read -p "" CONFIRM && [ "$$CONFIRM" = "yes" ] || (echo "Aborted."; exit 1)
	$(TERRAFORM) destroy

# Backup
.PHONY: backup
backup:
	@echo "Running backup tasks for $(ENV)..."
	$(ANSIBLE_PLAYBOOK) $(ANSIBLE_DIR)/playbooks/backup.yml --vault-password-file $(VAULT_PASSWORD_FILE)

# Security audit
.PHONY: security-audit
security-audit:
	@echo "Running security audit for $(ENV)..."
	$(ANSIBLE_PLAYBOOK) $(ANSIBLE_DIR)/playbooks/security.yml --vault-password-file $(VAULT_PASSWORD_FILE) -e "audit_only=true"

# Ethical audit
.PHONY: ethical-audit
ethical-audit:
	@echo "Running ethical audit for $(ENV)..."
	$(ANSIBLE_PLAYBOOK) $(ANSIBLE_DIR)/playbooks/ethical_audit.yml --vault-password-file $(VAULT_PASSWORD_FILE)

# Generate documentation
.PHONY: docs
docs:
	@echo "Generating documentation..."
	cd $(TERRAFORM_DIR) && terraform-docs markdown . > README.md
	mkdocs build

# Clean up
.PHONY: clean
clean:
	@echo "Cleaning up temporary files..."
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.retry" -delete
	find . -type f -name ".*.swp" -delete
	find . -type f -name ".DS_Store" -delete
	rm -f $(TERRAFORM_DIR)/environments/*/tfplan
	rm -f $(TERRAFORM_DIR)/environments/*/.terraform.lock.hcl
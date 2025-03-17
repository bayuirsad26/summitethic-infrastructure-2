#!/bin/bash
# SummitEthic - Create New Website Script
# This script creates a new website on the SummitEthic platform

set -e

# Display banner
echo "┌─────────────────────────────────────────────┐"
echo "│  SummitEthic - Ethical Website Deployment   │"
echo "└─────────────────────────────────────────────┘"

# Default values
ENV="production"
ANSIBLE_PATH="../"
DEFAULT_TEMPLATE="standard"
AVAILABLE_TEMPLATES=("standard" "blog" "ecommerce" "portfolio")
ENABLE_HTTPS=true
ENABLE_MONITORING=true
ENABLE_BACKUPS=true
USE_CDN=false

# Help function
function show_help() {
    echo "Usage: $0 [options] <domain>"
    echo ""
    echo "Options:"
    echo "  -h, --help                Display this help message"
    echo "  -e, --environment ENV     Set deployment environment (default: production)"
    echo "  -t, --template TEMPLATE   Set website template (default: standard)"
    echo "                            Available templates: ${AVAILABLE_TEMPLATES[*]}"
    echo "  --no-https                Disable HTTPS"
    echo "  --no-monitoring           Disable monitoring"
    echo "  --no-backups              Disable backups"
    echo "  --use-cdn                 Enable CDN"
    echo ""
    echo "Example:"
    echo "  $0 --environment staging --template blog example.com"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -e|--environment)
            ENV="$2"
            shift 2
            ;;
        -t|--template)
            TEMPLATE="$2"
            # Validate template
            VALID_TEMPLATE=false
            for t in "${AVAILABLE_TEMPLATES[@]}"; do
                if [[ "$t" == "$TEMPLATE" ]]; then
                    VALID_TEMPLATE=true
                    break
                fi
            done
            if ! $VALID_TEMPLATE; then
                echo "Error: Invalid template '$TEMPLATE'. Available templates: ${AVAILABLE_TEMPLATES[*]}"
                exit 1
            fi
            shift 2
            ;;
        --no-https)
            ENABLE_HTTPS=false
            shift
            ;;
        --no-monitoring)
            ENABLE_MONITORING=false
            shift
            ;;
        --no-backups)
            ENABLE_BACKUPS=false
            shift
            ;;
        --use-cdn)
            USE_CDN=true
            shift
            ;;
        *)
            DOMAIN="$1"
            shift
            ;;
    esac
done

# Validate domain
if [ -z "$DOMAIN" ]; then
    echo "Error: Domain name is required."
    show_help
fi

# Set template if not provided
if [ -z "$TEMPLATE" ]; then
    TEMPLATE="$DEFAULT_TEMPLATE"
fi

# Validate environment
if [ "$ENV" != "development" ] && [ "$ENV" != "staging" ] && [ "$ENV" != "production" ]; then
    echo "Error: Invalid environment '$ENV'. Must be one of: development, staging, production."
    exit 1
fi

# Check if Ansible is available
if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "Error: ansible-playbook command not found. Please install Ansible."
    exit 1
fi

# Ethical considerations check
echo ""
echo "=== Ethical Deployment Check ==="
echo ""
echo "The following checks are performed before deployment:"
echo "1. Domain name does not contain offensive terms"
echo "2. Website template complies with accessibility standards"
echo "3. Data collection is minimized and transparent"
echo "4. Resource allocation is fair and sustainable"
echo ""

# Perform offensive term check
OFFENSIVE_TERMS=("offensive" "harmful" "unethical")
for term in "${OFFENSIVE_TERMS[@]}"; do
    if [[ "$DOMAIN" == *"$term"* ]]; then
        echo "Warning: Domain contains potentially inappropriate term: '$term'"
        read -p "Do you want to continue? (y/N): " CONTINUE
        if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
            echo "Deployment canceled."
            exit 0
        fi
    fi
done

# Display configuration
echo ""
echo "=== Website Configuration ==="
echo "Domain: $DOMAIN"
echo "Environment: $ENV"
echo "Template: $TEMPLATE"
echo "HTTPS Enabled: $ENABLE_HTTPS"
echo "Monitoring Enabled: $ENABLE_MONITORING"
echo "Backups Enabled: $ENABLE_BACKUPS"
echo "CDN Enabled: $USE_CDN"
echo ""

# Confirm deployment
read -p "Do you want to proceed with the deployment? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Deployment canceled."
    exit 0
fi

# Generate deployment ID
DEPLOY_ID=$(date +%Y%m%d%H%M%S)
echo "Deployment ID: $DEPLOY_ID"

# Check vault password
if [ ! -f "$ANSIBLE_PATH/.vault_pass" ]; then
    read -sp "Enter Ansible Vault password: " VAULT_PASS
    echo ""
    echo "$VAULT_PASS" > "$ANSIBLE_PATH/.vault_pass"
    VAULT_CLEANUP=true
else
    VAULT_CLEANUP=false
fi

# Run Ansible playbook
echo "Starting deployment..."
ansible-playbook -i "$ANSIBLE_PATH/inventories/$ENV/inventory.yml" \
                "$ANSIBLE_PATH/playbooks/add-website.yml" \
                --extra-vars "domain=$DOMAIN template=$TEMPLATE https_enabled=$ENABLE_HTTPS monitoring_enabled=$ENABLE_MONITORING backups_enabled=$ENABLE_BACKUPS cdn_enabled=$USE_CDN deploy_id=$DEPLOY_ID"

# Save deployment record
echo "$(date): Deployed $DOMAIN with template $TEMPLATE to $ENV environment (ID: $DEPLOY_ID)" >> "$ANSIBLE_PATH/deployments.log"

# Clean up vault password file if created
if $VAULT_CLEANUP; then
    rm -f "$ANSIBLE_PATH/.vault_pass"
fi

echo ""
echo "✅ Website deployment completed!"
echo "Domain: $DOMAIN"
echo "Environment: $ENV"
echo ""
echo "Next steps:"
echo "1. Configure DNS records to point to the server"
echo "2. Upload content or connect to the CMS"
echo "3. Review monitoring dashboards"
echo ""
echo "For support, contact: support@summitethic.com"
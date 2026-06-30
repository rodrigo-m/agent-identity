#!/bin/bash
# ==============================================================================
# Google Cloud VPC and Compute Provisioning Script
# This script enables Compute Engine, creates a Custom VPC Network, and provisions
# a Subnet with the CIDR range 10.33.1.0/24 (covering 10.33.1.1/24 subnet).
# ==============================================================================

# Exit immediately if any command fails
set -euo pipefail

# Configurations
PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-your-gcp-project-id}"
NETWORK_NAME="agent-vpc"
SUBNET_NAME="agent-subnet"
REGION="us-central1"
SUBNET_RANGE="10.33.1.0/24" # Standard CIDR matching the 10.33.1.1/24 subnet range

echo "======================================================================"
echo "Starting VPC and Compute Setup for Project: ${PROJECT_ID}"
echo "======================================================================"

# Ensure the Google Cloud project exists; create it if it does not
echo "Checking if project '${PROJECT_ID}' exists..."
if gcloud projects describe "${PROJECT_ID}" &>/dev/null; then
    echo "Project '${PROJECT_ID}' already exists."
else
    echo "Project '${PROJECT_ID}' does not exist. Creating it..."
    gcloud projects create "${PROJECT_ID}"
    echo "Project created successfully!"
fi

# Ensure gcloud is configured to our project
echo "Setting current project context..."
gcloud config set project "${PROJECT_ID}"

# 1. Enable Compute Engine API
echo "Enabling Compute Engine API (compute.googleapis.com)..."
gcloud services enable compute.googleapis.com

# 2. Create the Custom VPC Network
echo "Creating Custom VPC Network: ${NETWORK_NAME}..."
if gcloud compute networks describe "${NETWORK_NAME}" &>/dev/null; then
    echo "VPC Network '${NETWORK_NAME}' already exists."
else
    gcloud compute networks create "${NETWORK_NAME}" \
        --subnet-mode=custom \
        --bgp-routing-mode=regional
    echo "Custom VPC Network created successfully!"
fi

# 3. Create the Custom Subnetwork
echo "Creating Custom Subnetwork '${SUBNET_NAME}' in region '${REGION}' with range '${SUBNET_RANGE}'..."
if gcloud compute networks subnets describe "${SUBNET_NAME}" --region="${REGION}" &>/dev/null; then
    echo "Subnetwork '${SUBNET_NAME}' already exists in region '${REGION}'."
else
    gcloud compute networks subnets create "${SUBNET_NAME}" \
        --network="${NETWORK_NAME}" \
        --region="${REGION}" \
        --range="${SUBNET_RANGE}" \
        --enable-private-ip-google-access
    echo "Subnetwork created successfully!"
fi

# 4. Create standard Firewall Rules (Allow SSH and ICMP)
FIREWALL_SSH="allow-ssh-ingress"
echo "Creating Firewall Rule to allow SSH ingress (${FIREWALL_SSH})..."
if gcloud compute firewall-rules describe "${FIREWALL_SSH}" &>/dev/null; then
    echo "Firewall rule '${FIREWALL_SSH}' already exists."
else
    gcloud compute firewall-rules create "${FIREWALL_SSH}" \
        --network="${NETWORK_NAME}" \
        --direction=INGRESS \
        --priority=65534 \
        --action=ALLOW \
        --rules=tcp:22 \
        --source-ranges=0.0.0.0/0 \
        --target-tags=allow-ssh
    echo "SSH Firewall rule created successfully!"
fi

echo "======================================================================"
echo "Setup Completed Successfully!"
echo "----------------------------------------------------------------------"
echo "You can now provision compute instances in this network. Example command:"
echo "gcloud compute instances create my-vm \\"
echo "    --project=${PROJECT_ID} \\"
echo "    --zone=${REGION}-a \\"
echo "    --subnet=${SUBNET_NAME} \\"
echo "    --tags=allow-ssh"
echo "======================================================================"
